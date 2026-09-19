-- T0.2 (P0 schema): reference data (SCHEMA.sql §11) — ingredient categories +
-- default shelf-life days. Treated as core app data (not a dev/test fixture,
-- which is what supabase/seed.sql is for): without these rows, category
-- pickers and default-shelf-life suggestions are empty.
-- ⚠ 这些是"起始估计值"，需要人工校对（TODO.md O-06 / T0.4）；不是食品安全建议，
-- UI 必须提示以包装日期和实际状态为准 (D14)。
insert into public.ingredient_categories (id, slug, name_zh, name_en, default_storage, shelf_fridge_days, shelf_freezer_days, shelf_pantry_days, sort_order) values
 (1,  'leafy',      '叶菜类',     'Leafy greens',        'fridge',  7,    null, null, 10),
 (2,  'root',       '根茎类',     'Root vegetables',     'pantry',  21,   null, 14,   20),
 (3,  'fruit_veg',  '瓜果茄类',   'Fruiting vegetables', 'fridge',  7,    null, 3,    30),
 (4,  'allium',     '葱姜蒜类',   'Alliums & aromatics', 'fridge',  14,   null, 14,   40),
 (5,  'mushroom',   '菌菇类',     'Mushrooms',           'fridge',  5,    null, null, 50),
 (6,  'meat',       '猪牛羊肉',   'Raw meat',            'fridge',  2,    90,   null, 60),
 (7,  'poultry',    '禽肉',       'Raw poultry',         'fridge',  2,    90,   null, 70),
 (8,  'seafood',    '水产',       'Seafood',             'fridge',  1,    60,   null, 80),
 (9,  'egg',        '蛋类',       'Eggs',                'fridge',  28,   null, 7,    90),
 (10, 'dairy',      '乳制品',     'Dairy',               'fridge',  7,    60,   null, 100),
 (11, 'tofu_soy',   '豆制品',     'Tofu & soy products', 'fridge',  5,    60,   null, 110),
 (12, 'grain',      '米面主食',   'Grains & noodles',    'pantry',  null, 180,  180,  120),
 (13, 'bread',      '面包烘焙',   'Bread & bakery',      'pantry',  7,    90,   4,    130),
 (14, 'fruit',      '水果',       'Fruit',               'fridge',  7,    null, 5,    140),
 (15, 'seasoning',  '调味料',     'Seasonings & sauces', 'pantry',  180,  null, 365,  150),
 (16, 'dried',      '干货',       'Dried goods',         'pantry',  null, null, 365,  160),
 (17, 'canned',     '罐头即食',   'Canned & packaged',   'pantry',  5,    null, 365,  170),
 (18, 'cooked',     '熟食剩菜',   'Cooked & leftovers',  'fridge',  3,    90,   null, 180),
 (19, 'other',      '其他',       'Other',               'pantry',  7,    null, 30,   190);
