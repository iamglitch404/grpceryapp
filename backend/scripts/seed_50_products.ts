import { createClient } from 'npm:@supabase/supabase-js';

const SUPABASE_URL = 'https://rrpcewnintodyxubueeu.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJycGNld25pbnRvZHl4dWJ1ZWV1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NjUyNzc4MSwiZXhwIjoyMTAyMTAzNzgxfQ.hgAg7Ak53OQfx45g95SekKp7mlJpLz9XsPhndOnqzWg';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface CategoryDef {
  name: string;
  slug: string;
  image_url: string;
  color_hex: string;
  sort_order: number;
  subcategories: {
    name: string;
    slug: string;
    description: string;
    image_url: string;
    sort_order: number;
  }[];
}

const CATEGORIES_DATA: CategoryDef[] = [
  {
    name: 'Fresh Vegetables',
    slug: 'fresh-vegetables',
    image_url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=600&q=80',
    color_hex: '#15803D',
    sort_order: 1,
    subcategories: [
      {
        name: 'Daily Veggies',
        slug: 'daily-veggies',
        description: 'Everyday cooking vegetables: onions, potatoes, tomatoes',
        image_url: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=600&q=80',
        sort_order: 1,
      },
      {
        name: 'Leafy Greens',
        slug: 'leafy-greens',
        description: 'Fresh farm spinach, coriander, mint, and greens',
        image_url: 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=600&q=80',
        sort_order: 2,
      },
      {
        name: 'Exotic & Seasonal',
        slug: 'exotic-seasonal',
        description: 'Broccoli, bell peppers, zucchini, mushrooms',
        image_url: 'https://images.unsplash.com/photo-1563565375-f3fdfdbefa83?auto=format&fit=crop&w=600&q=80',
        sort_order: 3,
      },
    ],
  },
  {
    name: 'Fresh Fruits',
    slug: 'fresh-fruits',
    image_url: 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?auto=format&fit=crop&w=600&q=80',
    color_hex: '#EA580C',
    sort_order: 2,
    subcategories: [
      {
        name: 'Daily Fruits',
        slug: 'daily-fruits',
        description: 'Bananas, apples, oranges, papayas for daily nutrition',
        image_url: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=600&q=80',
        sort_order: 1,
      },
      {
        name: 'Citrus & Berries',
        slug: 'citrus-berries',
        description: 'Lemons, oranges, grapes, and berries',
        image_url: 'https://images.unsplash.com/photo-1557800636-894a64c1696f?auto=format&fit=crop&w=600&q=80',
        sort_order: 2,
      },
      {
        name: 'Exotic & Melons',
        slug: 'exotic-melons',
        description: 'Watermelon, pineapple, kiwi, pomegranate',
        image_url: 'https://images.unsplash.com/photo-1589533610925-1cffc309ebaa?auto=format&fit=crop&w=600&q=80',
        sort_order: 3,
      },
    ],
  },
  {
    name: 'Dairy & Breakfast',
    slug: 'dairy-breakfast',
    image_url: 'https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=600&q=80',
    color_hex: '#0284C7',
    sort_order: 3,
    subcategories: [
      {
        name: 'Milk & Butter',
        slug: 'milk-butter',
        description: 'Pasteurized toned milk, butter, and cream',
        image_url: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=80',
        sort_order: 1,
      },
      {
        name: 'Paneer & Cheese',
        slug: 'paneer-cheese',
        description: 'Fresh malai paneer, cheddar, cheese slices',
        image_url: 'https://images.unsplash.com/photo-1589881133595-a3c085cb731d?auto=format&fit=crop&w=600&q=80',
        sort_order: 2,
      },
      {
        name: 'Eggs & Yogurt',
        slug: 'eggs-yogurt',
        description: 'Farm fresh eggs, fresh curd, and flavored yogurt',
        image_url: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=600&q=80',
        sort_order: 3,
      },
    ],
  },
  {
    name: 'Bakery & Bread',
    slug: 'bakery-bread',
    image_url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80',
    color_hex: '#D97706',
    sort_order: 4,
    subcategories: [
      {
        name: 'Fresh Breads & Buns',
        slug: 'fresh-breads-buns',
        description: 'Whole wheat, sandwich bread, pav, and burger buns',
        image_url: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?auto=format&fit=crop&w=600&q=80',
        sort_order: 1,
      },
      {
        name: 'Cookies & Rusks',
        slug: 'cookies-rusks',
        description: 'Crispy butter cookies, tea rusks, and brownies',
        image_url: 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&w=600&q=80',
        sort_order: 2,
      },
    ],
  },
  {
    name: 'Pantry & Cooking Essentials',
    slug: 'pantry-staples',
    image_url: 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=600&q=80',
    color_hex: '#B45309',
    sort_order: 5,
    subcategories: [
      {
        name: 'Rice, Atta & Grains',
        slug: 'rice-atta-grains',
        description: 'Basmati rice, chakki atta, pulses, and lentils',
        image_url: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=600&q=80',
        sort_order: 1,
      },
      {
        name: 'Oils & Ghee',
        slug: 'oils-ghee',
        description: 'Sunflower oil, mustard oil, cow ghee',
        image_url: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=600&q=80',
        sort_order: 2,
      },
      {
        name: 'Spices, Salt & Sugar',
        slug: 'spices-salt-sugar',
        description: 'Pure turmeric, chilli, garam masala, salt, and jaggery',
        image_url: 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=600&q=80',
        sort_order: 3,
      },
    ],
  },
  {
    name: 'Snacks & Munchies',
    slug: 'snacks-munchies',
    image_url: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?auto=format&fit=crop&w=600&q=80',
    color_hex: '#E11D48',
    sort_order: 6,
    subcategories: [
      {
        name: 'Chips & Namkeen',
        slug: 'chips-namkeen',
        description: 'Potato crisps, bhujia, kurkure, instant noodles',
        image_url: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?auto=format&fit=crop&w=600&q=80',
        sort_order: 1,
      },
      {
        name: 'Chocolates & Sweets',
        slug: 'chocolates-sweets',
        description: 'Milk chocolates, candy, and sweet delicacies',
        image_url: 'https://images.unsplash.com/photo-1548907040-4baa42d10919?auto=format&fit=crop&w=600&q=80',
        sort_order: 2,
      },
      {
        name: 'Nuts & Dry Fruits',
        slug: 'nuts-dry-fruits',
        description: 'California almonds, whole cashews, raisins, walnuts',
        image_url: 'https://images.unsplash.com/photo-1508061253366-f7da158b6d46?auto=format&fit=crop&w=600&q=80',
        sort_order: 3,
      },
    ],
  },
];

interface ProductSeedItem {
  title: string;
  categoryName: string;
  subcategoryName: string;
  description: string;
  pricePaise: number;
  originalPricePaise: number;
  unit: string;
  stockQuantity: number;
  imageUrl: string;
  isTodaysChoice: boolean;
  isSpecialDeal: boolean;
  isPopular: boolean;
  calories: string;
  productCode: string;
}

const PRODUCTS_SEED_DATA: ProductSeedItem[] = [
  // ── 1. Fresh Vegetables ───────────────────────────────────────────────────
  {
    title: 'Farm Fresh Red Tomatoes',
    categoryName: 'Fresh Vegetables',
    subcategoryName: 'Daily Veggies',
    description: 'Vine-ripened, juicy red tomatoes handpicked from local organic farms. Rich in Lycopene and Vitamin C, ideal for curries, salads, and soups.',
    pricePaise: 4500,
    originalPricePaise: 6000,
    unit: '1 kg',
    stockQuantity: 45,
    imageUrl: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: true,
    isPopular: true,
    calories: '18 kcal / 100g',
    productCode: 'VEG-TOM-001',
  },
  {
    title: 'Organic Red Onions (Nashik)',
    categoryName: 'Fresh Vegetables',
    subcategoryName: 'Daily Veggies',
    description: 'Crisp, pungent red onions sourced from Nashik farms. Essential aromatic staple for Indian gravies, tadkas, and fresh side salads.',
    pricePaise: 3800,
    originalPricePaise: 5000,
    unit: '1 kg',
    stockQuantity: 60,
    imageUrl: 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '40 kcal / 100g',
    productCode: 'VEG-ONI-002',
  },
  {
    title: 'Mountain Russet Potatoes',
    categoryName: 'Fresh Vegetables',
    subcategoryName: 'Daily Veggies',
    description: 'Grade-A earthy mountain potatoes with thin skin and fluffy texture when cooked. Perfect for roasting, fries, aloo parathas, and curries.',
    pricePaise: 3500,
    originalPricePaise: 4500,
    unit: '1 kg',
    stockQuantity: 55,
    imageUrl: 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '77 kcal / 100g',
    productCode: 'VEG-POT-003',
  },
  {
    title: 'Crisp Green Capsicum',
    categoryName: 'Fresh Vegetables',
    subcategoryName: 'Exotic & Seasonal',
    description: 'Glossy green bell peppers with crisp flesh and sweet herbal flavor. Great for Chinese stir-fries, pizza toppings, and stuffed capsicum recipes.',
    pricePaise: 4000,
    originalPricePaise: 5500,
    unit: '500 g',
    stockQuantity: 28,
    imageUrl: 'https://images.unsplash.com/photo-1563565375-f3fdfdbefa83?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: false,
    isPopular: false,
    calories: '20 kcal / 100g',
    productCode: 'VEG-CAP-004',
  },
  {
    title: 'Tender Baby Spinach (Palak)',
    categoryName: 'Fresh Vegetables',
    subcategoryName: 'Leafy Greens',
    description: 'Freshly harvested tender green spinach leaves. Packed with dietary iron, folate, and calcium for hearty palak paneer, dals, and green smoothies.',
    pricePaise: 2500,
    originalPricePaise: 3500,
    unit: '250 g',
    stockQuantity: 30,
    imageUrl: 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: true,
    calories: '23 kcal / 100g',
    productCode: 'VEG-PAL-005',
  },
  {
    title: 'Fresh Mountain Red Carrots',
    categoryName: 'Fresh Vegetables',
    subcategoryName: 'Daily Veggies',
    description: 'Crunchy sweet red carrots full of beta-carotene and dietary fiber. Delicious raw in salads or cooked into traditional Gajar ka Halwa.',
    pricePaise: 3200,
    originalPricePaise: 4200,
    unit: '500 g',
    stockQuantity: 35,
    imageUrl: 'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '41 kcal / 100g',
    productCode: 'VEG-CAR-006',
  },
  {
    title: 'English Salad Cucumber',
    categoryName: 'Fresh Vegetables',
    subcategoryName: 'Daily Veggies',
    description: 'Seedless, thin-skinned English cucumbers with crisp, hydrating crunch. 95% water content, great for hydration, raitas, and green juices.',
    pricePaise: 2800,
    originalPricePaise: 3800,
    unit: '500 g',
    stockQuantity: 40,
    imageUrl: 'https://images.unsplash.com/photo-1604977042946-1eecc30f269e?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '15 kcal / 100g',
    productCode: 'VEG-CUC-007',
  },
  {
    title: 'Farm Fresh Snow White Cauliflower',
    categoryName: 'Fresh Vegetables',
    subcategoryName: 'Daily Veggies',
    description: 'Compact, tightly packed snow-white cauliflower head free from spots. High in fiber and Vitamin C, great for Gobi Aloo and paratha fillings.',
    pricePaise: 4500,
    originalPricePaise: 6000,
    unit: '1 pc (Approx 700g)',
    stockQuantity: 25,
    imageUrl: 'https://images.unsplash.com/photo-1568584711075-3d021a7c3ca3?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: false,
    calories: '25 kcal / 100g',
    productCode: 'VEG-CAU-008',
  },
  {
    title: 'Sweet Green Garden Peas (Matar)',
    categoryName: 'Fresh Vegetables',
    subcategoryName: 'Daily Veggies',
    description: 'Tender, naturally sweet green peas pods. Rich in protein and antioxidants, fantastic for Matar Paneer, Pulao, and samosa stuffings.',
    pricePaise: 6500,
    originalPricePaise: 8500,
    unit: '500 g',
    stockQuantity: 22,
    imageUrl: 'https://images.unsplash.com/photo-1587735243615-c03f25aaff15?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '81 kcal / 100g',
    productCode: 'VEG-PEA-009',
  },
  {
    title: 'Organic Green Broccoli Florets',
    categoryName: 'Fresh Vegetables',
    subcategoryName: 'Exotic & Seasonal',
    description: 'Fresh organic green broccoli florets grown without synthetic pesticides. A superfood rich in Vitamin K, sulforaphane, and dietary fiber.',
    pricePaise: 7500,
    originalPricePaise: 9900,
    unit: '1 pc (Approx 400g)',
    stockQuantity: 20,
    imageUrl: 'https://images.unsplash.com/photo-1459411621453-7b03977f4bfc?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: false,
    isPopular: true,
    calories: '34 kcal / 100g',
    productCode: 'VEG-BRO-010',
  },

  // ── 2. Fresh Fruits ───────────────────────────────────────────────────────
  {
    title: 'Kashmiri Royal Gala Apples',
    categoryName: 'Fresh Fruits',
    subcategoryName: 'Daily Fruits',
    description: 'Handpicked crisp red apples from the orchards of Kashmir. Sweet, aromatic, and crunchy, loaded with antioxidants and dietary fiber.',
    pricePaise: 16000,
    originalPricePaise: 21000,
    unit: '1 kg (Approx 5-6 pcs)',
    stockQuantity: 30,
    imageUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: true,
    isPopular: true,
    calories: '52 kcal / 100g',
    productCode: 'FRU-APP-011',
  },
  {
    title: 'Cavendish Fresh Yellow Bananas',
    categoryName: 'Fresh Fruits',
    subcategoryName: 'Daily Fruits',
    description: 'Naturally ripened, sweet golden Cavendish bananas. Provides instant natural energy with potassium and Vitamin B6. Perfect pre-workout snack.',
    pricePaise: 7000,
    originalPricePaise: 9000,
    unit: '1 Dozen (12 pcs)',
    stockQuantity: 50,
    imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '89 kcal / 100g',
    productCode: 'FRU-BAN-012',
  },
  {
    title: 'Nagpur Sweet Juicy Oranges',
    categoryName: 'Fresh Fruits',
    subcategoryName: 'Citrus & Berries',
    description: 'Sun-drenched sweet and tangy Nagpur oranges bursting with refreshing juice and Vitamin C. Boosts immunity and refreshes the palate.',
    pricePaise: 9500,
    originalPricePaise: 13000,
    unit: '1 kg',
    stockQuantity: 32,
    imageUrl: 'https://images.unsplash.com/photo-1582979512210-99b6a53386f9?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: false,
    calories: '47 kcal / 100g',
    productCode: 'FRU-ORA-013',
  },
  {
    title: 'Green Seedless Table Grapes',
    categoryName: 'Fresh Fruits',
    subcategoryName: 'Citrus & Berries',
    description: 'Plump, crispy green seedless grapes with a refreshing sweet bite. Washed and packed fresh for easy snacking, fruit chaats, and desserts.',
    pricePaise: 8500,
    originalPricePaise: 11000,
    unit: '500 g',
    stockQuantity: 26,
    imageUrl: 'https://images.unsplash.com/photo-1537640538966-79f369143f8f?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: false,
    isPopular: true,
    calories: '69 kcal / 100g',
    productCode: 'FRU-GRA-014',
  },
  {
    title: 'Semi-Ripe Sweet Red Papaya',
    categoryName: 'Fresh Fruits',
    subcategoryName: 'Daily Fruits',
    description: 'Golden-orange fleshed sweet papaya rich in papain enzymes for optimal digestion and gut health. Delicious in morning breakfast bowls.',
    pricePaise: 5500,
    originalPricePaise: 7500,
    unit: '1 pc (Approx 1 kg)',
    stockQuantity: 20,
    imageUrl: 'https://images.unsplash.com/photo-1517282009859-f000ec3b26fe?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '43 kcal / 100g',
    productCode: 'FRU-PAP-015',
  },
  {
    title: 'Queen Fresh Sweet Pineapple',
    categoryName: 'Fresh Fruits',
    subcategoryName: 'Exotic & Melons',
    description: 'Juicy tropical Queen pineapple with intense sweetness and fragrant aroma. Rich in Bromelain enzyme, ideal for fresh juices and fruit skewers.',
    pricePaise: 8000,
    originalPricePaise: 10500,
    unit: '1 pc',
    stockQuantity: 18,
    imageUrl: 'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: false,
    calories: '50 kcal / 100g',
    productCode: 'FRU-PIN-016',
  },
  {
    title: 'Ruby Red Pomegranate (Anar)',
    categoryName: 'Fresh Fruits',
    subcategoryName: 'Exotic & Melons',
    description: 'Glistening ruby-red arils packed with sweet-tart juice. Full of polyphenols and anti-inflammatory compounds that promote heart health.',
    pricePaise: 13000,
    originalPricePaise: 17000,
    unit: '500 g (Approx 2-3 pcs)',
    stockQuantity: 22,
    imageUrl: 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: false,
    isPopular: true,
    calories: '83 kcal / 100g',
    productCode: 'FRU-POM-017',
  },
  {
    title: 'Fresh Zespri Green Kiwi Pack',
    categoryName: 'Fresh Fruits',
    subcategoryName: 'Exotic & Melons',
    description: 'Imported green kiwis with bright tangy-sweet emerald flesh. One kiwi provides over 100% of your daily Vitamin C requirement.',
    pricePaise: 9900,
    originalPricePaise: 13500,
    unit: 'Pack of 3 pcs',
    stockQuantity: 25,
    imageUrl: 'https://images.unsplash.com/photo-1585059895524-72359e06133a?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '61 kcal / 100g',
    productCode: 'FRU-KIW-018',
  },
  {
    title: 'Kiran Seedless Sweet Watermelon',
    categoryName: 'Fresh Fruits',
    subcategoryName: 'Exotic & Melons',
    description: 'Deep red, crisp, thirst-quenching sweet watermelon. Highly hydrating with 92% water content and amino acids for muscle recovery.',
    pricePaise: 12000,
    originalPricePaise: 16000,
    unit: '1 pc (Approx 2.5-3 kg)',
    stockQuantity: 15,
    imageUrl: 'https://images.unsplash.com/photo-1589533610925-1cffc309ebaa?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: true,
    calories: '30 kcal / 100g',
    productCode: 'FRU-WAT-019',
  },

  // ── 3. Dairy & Breakfast ──────────────────────────────────────────────────
  {
    title: 'Amul Taaza Fresh Toned Milk',
    categoryName: 'Dairy & Breakfast',
    subcategoryName: 'Milk & Butter',
    description: 'Homogenized and pasteurized toned milk with 3.0% fat and 8.5% SNF. Excellent for daily tea, coffee, hot chocolate, and cereal bowls.',
    pricePaise: 6800,
    originalPricePaise: 7200,
    unit: '1 L Pouch',
    stockQuantity: 60,
    imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: false,
    isPopular: true,
    calories: '58 kcal / 100ml',
    productCode: 'DAI-MIL-020',
  },
  {
    title: 'Farm Fresh White Eggs (Pack of 12)',
    categoryName: 'Dairy & Breakfast',
    subcategoryName: 'Eggs & Yogurt',
    description: 'Farm-fresh, clean-shelled white eggs rich in high-quality complete protein and essential amino acids. Sourced from hygienically raised poultry.',
    pricePaise: 9600,
    originalPricePaise: 11500,
    unit: 'Pack of 12 pcs',
    stockQuantity: 40,
    imageUrl: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: true,
    calories: '72 kcal / egg',
    productCode: 'DAI-EGG-021',
  },
  {
    title: 'Amul Pure Salted Butter',
    categoryName: 'Dairy & Breakfast',
    subcategoryName: 'Milk & Butter',
    description: 'The iconic "Utterly Butterly Delicious" salted butter made from fresh dairy cream. Spreads smoothly on warm toasts, parathas, and pav bhaji.',
    pricePaise: 5800,
    originalPricePaise: 6200,
    unit: '100 g Block',
    stockQuantity: 48,
    imageUrl: 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '717 kcal / 100g',
    productCode: 'DAI-BUT-022',
  },
  {
    title: 'Fresh Malai Paneer Cubes',
    categoryName: 'Dairy & Breakfast',
    subcategoryName: 'Paneer & Cheese',
    description: 'Melt-in-mouth soft cottage cheese prepared from pure buffalo milk. Unpressed and moist, ideal for Shahi Paneer, tikka skewers, and stir fries.',
    pricePaise: 9000,
    originalPricePaise: 10500,
    unit: '200 g Pack',
    stockQuantity: 34,
    imageUrl: 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: false,
    isPopular: true,
    calories: '265 kcal / 100g',
    productCode: 'DAI-PAN-023',
  },
  {
    title: 'Mother Dairy Classic Dahi (Curd)',
    categoryName: 'Dairy & Breakfast',
    subcategoryName: 'Eggs & Yogurt',
    description: 'Thick, creamy, set curd packed with live active probiotics. Aids digestion and cooling; excellent for raitas, chaats, and lassi.',
    pricePaise: 4000,
    originalPricePaise: 4500,
    unit: '400 g Tub',
    stockQuantity: 30,
    imageUrl: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '61 kcal / 100g',
    productCode: 'DAI-CUR-024',
  },
  {
    title: 'Amul Processed Cheese Slices',
    categoryName: 'Dairy & Breakfast',
    subcategoryName: 'Paneer & Cheese',
    description: 'Individually wrapped creamy processed cheddar cheese slices. Melts smoothly over burgers, grilled toasties, and homemade pizzas.',
    pricePaise: 14000,
    originalPricePaise: 16000,
    unit: '200 g (10 Slices)',
    stockQuantity: 28,
    imageUrl: 'https://images.unsplash.com/photo-1624806992066-5ffcf7ca186b?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: true,
    calories: '310 kcal / 100g',
    productCode: 'DAI-CHE-025',
  },
  {
    title: 'Epigamia Greek Strawberry Yogurt',
    categoryName: 'Dairy & Breakfast',
    subcategoryName: 'Eggs & Yogurt',
    description: 'Strained authentic Greek yogurt infused with real strawberry pulp. High protein (6g per cup) with zero preservatives for guilt-free sweet cravings.',
    pricePaise: 4500,
    originalPricePaise: 5500,
    unit: '100 g Cup',
    stockQuantity: 20,
    imageUrl: 'https://images.unsplash.com/photo-1571212515416-fef01fc43637?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '98 kcal / 100g',
    productCode: 'DAI-YOG-026',
  },
  {
    title: 'Nestle Sweetened Condensed Milk',
    categoryName: 'Dairy & Breakfast',
    subcategoryName: 'Milk & Butter',
    description: 'Rich and creamy sweetened condensed milk made from pure cows milk. Indispensable secret ingredient for kheer, fudge, cakes, and desserts.',
    pricePaise: 14500,
    originalPricePaise: 16000,
    unit: '380 g Tin',
    stockQuantity: 22,
    imageUrl: 'https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '321 kcal / 100g',
    productCode: 'DAI-CON-027',
  },

  // ── 4. Bakery & Bread ─────────────────────────────────────────────────────
  {
    title: '100% Whole Wheat Artisanal Brown Bread',
    categoryName: 'Bakery & Bread',
    subcategoryName: 'Fresh Breads & Buns',
    description: 'Freshly baked bakery loaf prepared from 100% whole grain wheat with zero added maida. High fiber slices for healthy breakfast sandwiches.',
    pricePaise: 5000,
    originalPricePaise: 6000,
    unit: '400 g Loaf',
    stockQuantity: 30,
    imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: false,
    isPopular: true,
    calories: '245 kcal / 100g',
    productCode: 'BAK-BRN-028',
  },
  {
    title: 'Soft White Sandwich Milk Bread',
    categoryName: 'Bakery & Bread',
    subcategoryName: 'Fresh Breads & Buns',
    description: 'Ultra-soft, pillow-fluffy white milk bread with tender golden crust. Perfect for kids tiffins, butter toast, and clubhouse sandwiches.',
    pricePaise: 4200,
    originalPricePaise: 4800,
    unit: '400 g Loaf',
    stockQuantity: 35,
    imageUrl: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '260 kcal / 100g',
    productCode: 'BAK-WHT-029',
  },
  {
    title: 'Brioche Sesame Burger Buns',
    categoryName: 'Bakery & Bread',
    subcategoryName: 'Fresh Breads & Buns',
    description: 'Rich buttery brioche burger buns topped with toasted sesame seeds. Holds juicy patties without crumbling or turning soggy.',
    pricePaise: 3500,
    originalPricePaise: 4500,
    unit: 'Pack of 2 pcs',
    stockQuantity: 20,
    imageUrl: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: false,
    calories: '280 kcal / 100g',
    productCode: 'BAK-BUN-030',
  },
  {
    title: 'Britannia Good Day Rich Butter Cookies',
    categoryName: 'Bakery & Bread',
    subcategoryName: 'Cookies & Rusks',
    description: 'Golden, crumbly butter cookies loaded with rich churned butter and cashew essence. Iconic smile pattern that pairs delightfully with hot tea.',
    pricePaise: 4000,
    originalPricePaise: 4500,
    unit: '200 g Pack',
    stockQuantity: 40,
    imageUrl: 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '495 kcal / 100g',
    productCode: 'BAK-COO-031',
  },
  {
    title: 'Dark Chocolate Fudge Brownie Muffins',
    categoryName: 'Bakery & Bread',
    subcategoryName: 'Cookies & Rusks',
    description: 'Decadent moist chocolate muffins loaded with imported dark chocolate chips and Dutch cocoa. Microwave for 10 seconds for gooey lava center.',
    pricePaise: 7500,
    originalPricePaise: 9000,
    unit: 'Pack of 2 pcs',
    stockQuantity: 15,
    imageUrl: 'https://images.unsplash.com/photo-1586985289688-ca3cf47d3e6e?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: false,
    isPopular: false,
    calories: '380 kcal / 100g',
    productCode: 'BAK-MUF-032',
  },

  // ── 5. Pantry & Cooking Essentials ────────────────────────────────────────
  {
    title: 'India Gate Super Basmati Rice',
    categoryName: 'Pantry & Cooking Essentials',
    subcategoryName: 'Rice, Atta & Grains',
    description: 'Aged long-grain royal Basmati rice with exquisite aroma and slender pearls that elongate up to 2x upon boiling. Ideal for Biryanis and Pulaos.',
    pricePaise: 14500,
    originalPricePaise: 19000,
    unit: '1 kg Pouch',
    stockQuantity: 50,
    imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: true,
    isPopular: true,
    calories: '350 kcal / 100g',
    productCode: 'PAN-RIC-033',
  },
  {
    title: 'Aashirvaad Shudh Chakki Whole Wheat Atta',
    categoryName: 'Pantry & Cooking Essentials',
    subcategoryName: 'Rice, Atta & Grains',
    description: '100% pure stone-ground whole wheat atta with zero maida. Absorbs extra water to produce soft, golden, fluffy rotis that stay tender for hours.',
    pricePaise: 24000,
    originalPricePaise: 27500,
    unit: '5 kg Bag',
    stockQuantity: 40,
    imageUrl: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '364 kcal / 100g',
    productCode: 'PAN-ATT-034',
  },
  {
    title: 'Fortune Sunlite Refined Sunflower Oil',
    categoryName: 'Pantry & Cooking Essentials',
    subcategoryName: 'Oils & Ghee',
    description: 'Light, healthy refined sunflower cooking oil enriched with Vitamins A, D, and E. High smoke point makes it perfect for deep frying and sautés.',
    pricePaise: 13500,
    originalPricePaise: 16500,
    unit: '1 L Pouch',
    stockQuantity: 45,
    imageUrl: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: true,
    calories: '884 kcal / 100ml',
    productCode: 'PAN-OIL-035',
  },
  {
    title: 'Tata Sampann Unpolished Toor Dal',
    categoryName: 'Pantry & Cooking Essentials',
    subcategoryName: 'Rice, Atta & Grains',
    description: 'Nutrient-rich unpolished arhar/toor dal that retains natural dietary fiber and wholesome plant protein. Free from water, oil, or stone polish.',
    pricePaise: 16500,
    originalPricePaise: 19500,
    unit: '1 kg Pack',
    stockQuantity: 30,
    imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '343 kcal / 100g',
    productCode: 'PAN-DAL-036',
  },
  {
    title: 'Yellow Moong Dal Split (Dhuli)',
    categoryName: 'Pantry & Cooking Essentials',
    subcategoryName: 'Rice, Atta & Grains',
    description: 'Easy-to-digest yellow split lentils with rapid cooking time. Comfort food staple for khichdi, dal tadka, and healthy weight-loss soups.',
    pricePaise: 13500,
    originalPricePaise: 16000,
    unit: '1 kg Pack',
    stockQuantity: 35,
    imageUrl: 'https://images.unsplash.com/photo-1515543237350-b3eea1ec8082?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '347 kcal / 100g',
    productCode: 'PAN-MOO-037',
  },
  {
    title: 'Tata Salt Vacuum Evaporated Iodized Salt',
    categoryName: 'Pantry & Cooking Essentials',
    subcategoryName: 'Spices, Salt & Sugar',
    description: 'Desh Ka Namak — pure vacuum evaporated iodized salt. Provides consistent saltiness and essential dietary iodine for healthy brain development.',
    pricePaise: 2800,
    originalPricePaise: 3000,
    unit: '1 kg Packet',
    stockQuantity: 80,
    imageUrl: 'https://images.unsplash.com/photo-1518110925495-5fe2fda0442c?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '0 kcal',
    productCode: 'PAN-SLT-038',
  },
  {
    title: 'Everest Super Garam Masala Blend',
    categoryName: 'Pantry & Cooking Essentials',
    subcategoryName: 'Spices, Salt & Sugar',
    description: 'Aromatic master blend of 13 whole roasted spices including cardamom, cinnamon, clove, and mace. Adds warm depth to veg and non-veg curries.',
    pricePaise: 8500,
    originalPricePaise: 9500,
    unit: '100 g Box',
    stockQuantity: 40,
    imageUrl: 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: false,
    isPopular: true,
    calories: '380 kcal / 100g',
    productCode: 'PAN-MAS-039',
  },
  {
    title: 'Catch Pure Sun-Dried Turmeric Powder',
    categoryName: 'Pantry & Cooking Essentials',
    subcategoryName: 'Spices, Salt & Sugar',
    description: 'High curcumin content golden turmeric powder sourced from Erode finger roots. Powerful antioxidant and immunity-boosting everyday spice.',
    pricePaise: 6500,
    originalPricePaise: 7500,
    unit: '200 g Pouch',
    stockQuantity: 45,
    imageUrl: 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '312 kcal / 100g',
    productCode: 'PAN-TUR-040',
  },
  {
    title: 'Everest Kashmiri Lal Mirch Powder',
    categoryName: 'Pantry & Cooking Essentials',
    subcategoryName: 'Spices, Salt & Sugar',
    description: 'Specialty stemless Kashmiri red chilli powder that imparts radiant crimson color with mild, pleasant heat to curries and gravies.',
    pricePaise: 7500,
    originalPricePaise: 8800,
    unit: '100 g Box',
    stockQuantity: 38,
    imageUrl: 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: true,
    calories: '282 kcal / 100g',
    productCode: 'PAN-CHL-041',
  },
  {
    title: '24 Mantra Organic Pure Jaggery Powder (Gud)',
    categoryName: 'Pantry & Cooking Essentials',
    subcategoryName: 'Spices, Salt & Sugar',
    description: 'Chemical-free unrefined natural sugarcane jaggery powder. Wholesome mineral-rich iron alternative to refined white sugar for tea and sweets.',
    pricePaise: 6000,
    originalPricePaise: 7500,
    unit: '500 g Pouch',
    stockQuantity: 30,
    imageUrl: 'https://images.unsplash.com/photo-1587132137056-bfbf0166836e?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: false,
    calories: '383 kcal / 100g',
    productCode: 'PAN-JAG-042',
  },

  // ── 6. Snacks & Munchies ──────────────────────────────────────────────────
  {
    title: "Lay's India's Magic Masala Potato Chips",
    categoryName: 'Snacks & Munchies',
    subcategoryName: 'Chips & Namkeen',
    description: 'Thin crispy potato wafers coated in a tangy blend of classic Indian spices. The ultimate crunch snack for movies, parties, and tea time.',
    pricePaise: 2000,
    originalPricePaise: 2000,
    unit: '50 g Pouch',
    stockQuantity: 70,
    imageUrl: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '544 kcal / 100g',
    productCode: 'SNA-LAY-043',
  },
  {
    title: 'Kurkure Masala Munch Crispy Snack',
    categoryName: 'Snacks & Munchies',
    subcategoryName: 'Chips & Namkeen',
    description: 'Tedha Par Mera crunchy corn and dal puffs bursting with fiery chatpata masala seasoning. Cooked with rice bran oil with 0g trans fat.',
    pricePaise: 2000,
    originalPricePaise: 2000,
    unit: '85 g Pouch',
    stockQuantity: 65,
    imageUrl: 'https://images.unsplash.com/photo-1621447504864-d8686e12698c?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '561 kcal / 100g',
    productCode: 'SNA-KUR-044',
  },
  {
    title: "Haldiram's Nagpur Spicy Aloo Bhujia",
    categoryName: 'Snacks & Munchies',
    subcategoryName: 'Chips & Namkeen',
    description: 'Traditional crispy potato sev noodles seasoned with mint, red chilli, and spicy secret spices. Irresistible accompaniment to chai and drinks.',
    pricePaise: 5500,
    originalPricePaise: 6500,
    unit: '200 g Pack',
    stockQuantity: 45,
    imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: true,
    isPopular: true,
    calories: '580 kcal / 100g',
    productCode: 'SNA-BHU-045',
  },
  {
    title: 'Cadbury Dairy Milk Silk Chocolate Bar',
    categoryName: 'Snacks & Munchies',
    subcategoryName: 'Chocolates & Sweets',
    description: 'Silky smooth, rich milk chocolate that melts luxuriously in the mouth. Made with cocoa butter and creamy milk for special celebrations.',
    pricePaise: 8500,
    originalPricePaise: 9500,
    unit: '60 g Bar',
    stockQuantity: 50,
    imageUrl: 'https://images.unsplash.com/photo-1548907040-4baa42d10919?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: false,
    isPopular: true,
    calories: '532 kcal / 100g',
    productCode: 'SNA-CAD-046',
  },
  {
    title: 'Maggi 2-Minute Masala Instant Noodles',
    categoryName: 'Snacks & Munchies',
    subcategoryName: 'Chips & Namkeen',
    description: 'The beloved classic instant noodles with the iconic Tastemaker sachet of 10 roasted spices and iron fortification. Ready in just 2 minutes.',
    pricePaise: 5600,
    originalPricePaise: 6000,
    unit: 'Pack of 4 (280g)',
    stockQuantity: 60,
    imageUrl: 'https://images.unsplash.com/photo-1612927601601-6638404737ce?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '427 kcal / 100g',
    productCode: 'SNA-MAG-047',
  },
  {
    title: 'California Raw Crunchy Almonds (Badam)',
    categoryName: 'Snacks & Munchies',
    subcategoryName: 'Nuts & Dry Fruits',
    description: 'Hand-sorted nonpareil California almonds packed with plant protein, Vitamin E, and healthy omega fats. Ideal for soaking or guilt-free snacking.',
    pricePaise: 24000,
    originalPricePaise: 29000,
    unit: '250 g Pouch',
    stockQuantity: 30,
    imageUrl: 'https://images.unsplash.com/photo-1508061253366-f7da158b6d46?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: true,
    isSpecialDeal: true,
    isPopular: true,
    calories: '579 kcal / 100g',
    productCode: 'SNA-ALM-048',
  },
  {
    title: 'Whole King Cashew Nuts (Kaju W240)',
    categoryName: 'Snacks & Munchies',
    subcategoryName: 'Nuts & Dry Fruits',
    description: 'Jumbo W240 grade whole cashew nuts with naturally sweet, buttery crunch. Superb for kaju katli, creamy gravies, and healthy trail mixes.',
    pricePaise: 26500,
    originalPricePaise: 32000,
    unit: '250 g Pouch',
    stockQuantity: 28,
    imageUrl: 'https://images.unsplash.com/photo-1509358271058-acd22cc93898?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: false,
    isPopular: true,
    calories: '553 kcal / 100g',
    productCode: 'SNA-CAS-049',
  },
  {
    title: 'Golden Seedless Afghani Raisins (Kishmish)',
    categoryName: 'Snacks & Munchies',
    subcategoryName: 'Nuts & Dry Fruits',
    description: 'Sun-dried long green-golden raisins with concentrated natural sweetness and dietary iron. Perfect topping for morning oats, kheer, and halwa.',
    pricePaise: 12000,
    originalPricePaise: 15000,
    unit: '250 g Pouch',
    stockQuantity: 32,
    imageUrl: 'https://images.unsplash.com/photo-1589182373726-e4f658ab50f0?auto=format&fit=crop&w=600&q=80',
    isTodaysChoice: false,
    isSpecialDeal: true,
    isPopular: false,
    calories: '299 kcal / 100g',
    productCode: 'SNA-RAI-050',
  },
];

async function main() {
  console.log('🚀 Starting Category & 50 Products Seeding...');

  // 1. Map to store category and subcategory IDs
  const categoryMap = new Map<string, string>();
  const subcategoryMap = new Map<string, string>();

  // Fetch any existing categories
  const { data: existingCats } = await supabase.from('categories').select('*');
  for (const c of existingCats || []) {
    categoryMap.set(c.name.toLowerCase(), c.id);
  }

  // 2. Insert or update categories & subcategories
  for (const catDef of CATEGORIES_DATA) {
    let catId = categoryMap.get(catDef.name.toLowerCase());

    if (!catId) {
      const { data: createdCat, error: catErr } = await supabase
        .from('categories')
        .insert({
          name: catDef.name,
          slug: catDef.slug,
          image_url: catDef.image_url,
          color_hex: catDef.color_hex,
          sort_order: catDef.sort_order,
          is_active: true,
        })
        .select()
        .single();

      if (catErr) {
        console.error(`Error inserting category ${catDef.name}:`, catErr.message);
        continue;
      }
      catId = createdCat.id;
      categoryMap.set(catDef.name.toLowerCase(), catId);
      console.log(`✅ Created Category: ${catDef.name} (${catId})`);
    } else {
      console.log(`ℹ️ Category exists: ${catDef.name} (${catId})`);
    }

    // Insert subcategories
    for (const subDef of catDef.subcategories) {
      const key = `${catId}:${subDef.name.toLowerCase()}`;
      const { data: existingSub } = await supabase
        .from('subcategories')
        .select('id')
        .eq('category_id', catId)
        .eq('name', subDef.name)
        .maybeSingle();

      if (!existingSub) {
        const { data: createdSub, error: subErr } = await supabase
          .from('subcategories')
          .insert({
            category_id: catId,
            name: subDef.name,
            slug: subDef.slug,
            description: subDef.description,
            image_url: subDef.image_url,
            sort_order: subDef.sort_order,
            is_active: true,
          })
          .select()
          .single();

        if (subErr) {
          console.error(`Error inserting subcategory ${subDef.name}:`, subErr.message);
          continue;
        }
        subcategoryMap.set(key, createdSub.id);
        console.log(`  └─ Created Subcategory: ${subDef.name} (${createdSub.id})`);
      } else {
        subcategoryMap.set(key, existingSub.id);
        console.log(`  └─ Subcategory exists: ${subDef.name} (${existingSub.id})`);
      }
    }
  }

  // 3. Clear any existing products to prevent duplicates and seed fresh
  console.log('📦 Seeding 50 Products...');
  let insertedCount = 0;

  for (const item of PRODUCTS_SEED_DATA) {
    const catId = categoryMap.get(item.categoryName.toLowerCase());
    const subKey = catId ? `${catId}:${item.subcategoryName.toLowerCase()}` : '';
    const subId = subcategoryMap.get(subKey) || null;

    // Check if product with this title already exists
    const { data: existingProd } = await supabase
      .from('products')
      .select('id')
      .eq('title', item.title)
      .maybeSingle();

    const productPayload = {
      title: item.title,
      description: item.description,
      price_paise: item.pricePaise,
      original_price_paise: item.originalPricePaise,
      unit: item.unit,
      stock_quantity: item.stockQuantity,
      image_url: item.imageUrl,
      category_id: catId || null,
      subcategory_id: subId || null,
      product_code: item.productCode,
      is_todays_choice: item.isTodaysChoice,
      is_special_deal: item.isSpecialDeal,
      is_popular: item.isPopular,
      is_active: true,
      approval_status: 'listed',
      calories: item.calories,
      delivery_time_minutes: 20,
    };

    if (existingProd) {
      const { error: updateErr } = await supabase
        .from('products')
        .update(productPayload)
        .eq('id', existingProd.id);

      if (updateErr) {
        console.error(`Error updating product ${item.title}:`, updateErr.message);
      } else {
        insertedCount++;
        console.log(`  [${insertedCount}/50] 🔄 Updated: ${item.title}`);
      }
    } else {
      const { error: insertErr } = await supabase
        .from('products')
        .insert(productPayload);

      if (insertErr) {
        console.error(`Error inserting product ${item.title}:`, insertErr.message);
      } else {
        insertedCount++;
        console.log(`  [${insertedCount}/50] ✨ Inserted: ${item.title}`);
      }
    }
  }

  console.log(`\n🎉 DONE! Successfully seeded/updated ${insertedCount} products in the database!`);
}

main().catch(console.error);
