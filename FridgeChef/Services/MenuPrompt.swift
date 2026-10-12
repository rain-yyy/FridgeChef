import Foundation

/// Builds the menu request for the AI and turns its JSON reply into validated plans.
enum MenuPrompt {
    /// A fridge item offered to the AI, referred to by a short ref ("i1") instead of its UUID.
    struct Candidate: Equatable {
        let ref: String
        let itemID: UUID
        let name: String
        let quantity: Double
        let unit: QuantityUnit
        let storage: StorageLocation
        let daysLeft: Int?
        let isSoon: Bool
    }

    /// Everything not expired (frozen included), use-soon items first, then by days left.
    static func candidates(from items: [FoodItem]) -> [Candidate] {
        items
            .filter { !$0.expiryStatus.isExpired && $0.quantity > 0 }
            .sorted { FridgeSections.inDisplayOrder($0, $1) }
            .enumerated()
            .map { index, item in
                Candidate(
                    ref: "i\(index + 1)", itemID: item.id, name: item.name, quantity: item.quantity,
                    unit: item.unit, storage: item.storage, daysLeft: item.daysLeft,
                    isSoon: item.expiryStatus.isSoon)
            }
    }

    // MARK: - Request

    static func messages(
        candidates: [Candidate], cuisine: Cuisine, servings: Int, languageName: String
    ) -> [ChatMessage] {
        let cuisineName = cuisine == .chinese ? "Chinese" : "Western"
        let system = """
            You are a home-cooking assistant. Plan meals from the user's fridge.
            Rules:
            - Return exactly 3 different plans. Each plan is one complete \(cuisineName) meal of 1-3 dishes for \(servings) \(servings == 1 ? "person" : "people").
            - Use ONLY the fridge ingredients listed by the user, referring to each by its ref (e.g. "i3"). Never invent fridge ingredients.
            - Prefer ingredients marked use_soon; together the plans should use as many of them as possible.
            - Seasonings and pantry staples (oil, salt, sugar, soy sauce, vinegar, garlic, ginger, scallion, starch, spices...) are assumed to be at home. Put them in "extras", never in "ingredients".
            - "amount" is in the ingredient's own unit, a multiple of 0.5, and never more than what is available.
            - If a plan uses a frozen ingredient, set "note" to a short reminder to thaw it first; otherwise "note" is null.
            - "minutes" is the total cooking time for the whole meal.
            - Each dish has 3-6 short, practical steps.
            - Write every human-readable text (dish names, extras, steps, note) in \(languageName).
            - Reply with JSON only, matching the given schema.
            """
        let lines = candidates.map { c in
            var parts = [c.ref, c.name, c.unit.amountText(c.quantity)]
            if c.storage == .freezer {
                parts.append("frozen")
            } else if let days = c.daysLeft {
                parts.append("fridge, \(days) day(s) left")
            } else {
                parts.append("fridge")
            }
            if c.isSoon { parts.append("use_soon") }
            return parts.joined(separator: " | ")
        }
        let user = "My fridge (ref | name | available | storage | flags):\n" + lines.joined(separator: "\n")
        return [ChatMessage(role: .system, content: system), ChatMessage(role: .user, content: user)]
    }

    /// Strict JSON schema for the reply (OpenRouter structured outputs).
    static let responseFormat: [String: Any] = {
        func object(_ properties: [String: Any]) -> [String: Any] {
            ["type": "object", "properties": properties,
             "required": Array(properties.keys).sorted(), "additionalProperties": false]
        }
        let ingredient = object(["ref": ["type": "string"], "amount": ["type": "number"]])
        let dish = object([
            "name": ["type": "string"],
            "ingredients": ["type": "array", "items": ingredient],
            "extras": ["type": "array", "items": ["type": "string"]],
            "steps": ["type": "array", "items": ["type": "string"]],
        ])
        let plan = object([
            "minutes": ["type": "integer"],
            "note": ["type": ["string", "null"]],
            "dishes": ["type": "array", "items": dish],
        ])
        let schema = object(["plans": ["type": "array", "items": plan, "minItems": 3, "maxItems": 3]])
        return ["type": "json_schema", "json_schema": ["name": "menu", "strict": true, "schema": schema]]
    }()

    // MARK: - Response

    /// Decodes and validates the reply. Unknown refs and non-positive amounts are dropped, amounts are
    /// rounded to 0.5 and capped at what is available. Fewer than 2 usable plans is a bad response.
    /// Returns at most 3 plans, the ones using more use-soon items first.
    static func parse(_ content: String, candidates: [Candidate]) throws(AIError) -> [MenuPlan] {
        guard let json = extractJSON(content),
              let raw = try? JSONDecoder().decode(RawMenu.self, from: Data(json.utf8)) else {
            throw .badResponse
        }
        let byRef = Dictionary(candidates.map { ($0.ref.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })

        let plans: [MenuPlan] = (raw.plans ?? []).compactMap { rawPlan in
            let dishes: [Dish] = (rawPlan.dishes ?? []).compactMap { rawDish in
                let name = rawDish.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !name.isEmpty else { return nil }
                let ingredients: [DishIngredient] = (rawDish.ingredients ?? []).compactMap { rawIngredient in
                    guard let ref = rawIngredient.ref?.trimmingCharacters(in: .whitespaces).lowercased(),
                          let candidate = byRef[ref],
                          let amount = rawIngredient.amount, amount > 0 else { return nil }
                    let rounded = min(max((amount * 2).rounded() / 2, 0.5), candidate.quantity)
                    return DishIngredient(
                        itemID: candidate.itemID, name: candidate.name, unit: candidate.unit,
                        amount: rounded, wasSoon: candidate.isSoon)
                }
                return Dish(
                    name: name, ingredients: ingredients,
                    extras: cleaned(rawDish.extras), steps: cleaned(rawDish.steps))
            }
            guard dishes.contains(where: { !$0.ingredients.isEmpty }) else { return nil }
            let note = rawPlan.note?.trimmingCharacters(in: .whitespacesAndNewlines)
            return MenuPlan(minutes: rawPlan.minutes.flatMap { $0 > 0 ? $0 : nil },
                            note: note?.isEmpty == false ? note : nil, dishes: dishes)
        }

        guard plans.count >= 2 else { throw .badResponse }
        // Stable sort: ties keep the AI's order.
        return plans.enumerated()
            .sorted { ($0.element.soonItemCount, -$0.offset) > ($1.element.soonItemCount, -$1.offset) }
            .prefix(3)
            .map(\.element)
    }

    /// The outermost {...} in the reply, which may be wrapped in a ```json fence or prose.
    static func extractJSON(_ content: String) -> String? {
        guard let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"), start < end else {
            return nil
        }
        return String(content[start...end])
    }

    private static func cleaned(_ strings: [String]?) -> [String] {
        (strings ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

// Lenient mirror of the schema: every field optional so one bad field doesn't sink the whole reply.
private struct RawMenu: Decodable {
    let plans: [RawPlan]?
}

private struct RawPlan: Decodable {
    let minutes: Int?
    let note: String?
    let dishes: [RawDish]?

    enum CodingKeys: CodingKey { case minutes, note, dishes }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minutes = (try? container.decode(Int.self, forKey: .minutes))
            ?? (try? container.decode(Double.self, forKey: .minutes)).map { Int($0) }
        note = try? container.decode(String.self, forKey: .note)
        dishes = try? container.decode([RawDish].self, forKey: .dishes)
    }
}

private struct RawDish: Decodable {
    let name: String?
    let ingredients: [RawIngredient]?
    let extras: [String]?
    let steps: [String]?

    enum CodingKeys: CodingKey { case name, ingredients, extras, steps }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try? container.decode(String.self, forKey: .name)
        ingredients = try? container.decode([RawIngredient].self, forKey: .ingredients)
        extras = try? container.decode([String].self, forKey: .extras)
        steps = try? container.decode([String].self, forKey: .steps)
    }
}

private struct RawIngredient: Decodable {
    let ref: String?
    let amount: Double?

    enum CodingKeys: CodingKey { case ref, amount }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ref = try? container.decode(String.self, forKey: .ref)
        amount = (try? container.decode(Double.self, forKey: .amount))
            ?? (try? container.decode(String.self, forKey: .amount)).flatMap(Double.init)
    }
}
