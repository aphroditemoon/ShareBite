const express = require('express');
const router = express.Router();
const { query } = require('../db/pool');
const { formatListing } = require('../utils/formatters');

const ML_SERVICE_URL = (process.env.ML_SERVICE_URL || '').replace(/\/$/, '');

async function callPythonMl(payload) {
  if (!ML_SERVICE_URL || typeof fetch !== 'function') return null;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 2500);

  try {
    const response = await fetch(`${ML_SERVICE_URL}/recommend`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    if (!response.ok) return null;
    const body = await response.json();
    return body && body.success ? body.data : null;
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}


const FOOD_DATA = {
  ingredients_to_recipes: {
    chicken: ['Crispy Fried Chicken', 'Chicken Soup', 'Grilled Chicken', 'Chicken Rice'],
    rice: ['Fried Rice', 'Rice Bowl', 'Congee', 'Nasi Uduk'],
    egg: ['Scrambled Eggs', 'Omelette', 'Egg Fried Rice', 'Egg Salad'],
    tofu: ['Stir-fried Tofu', 'Tofu Soup', 'Grilled Tofu'],
    tempeh: ['Crispy Tempeh', 'Tempeh Stir-fry', 'Sweet Tempeh'],
    spinach: ['Sauteed Spinach', 'Spinach Soup', 'Spinach Omelette'],
    carrot: ['Carrot Stir-fry', 'Mixed Veggie Soup', 'Carrot Salad'],
    banana: ['Banana Pancakes', 'Banana Smoothie', 'Banana Bread', 'Fried Banana'],
    noodle: ['Stir-fried Noodles', 'Noodle Soup', 'Cold Noodles'],
    bread: ['French Toast', 'Sandwich', 'Bread Pudding'],
    potato: ['Mashed Potatoes', 'Potato Soup', 'Hash Browns', 'Potato Wedges'],
    fish: ['Pan-fried Fish', 'Fish Curry', 'Fish Tacos', 'Grilled Fish'],
    tomato: ['Tomato Sauce', 'Tomato Soup', 'Salsa'],
    mushroom: ['Mushroom Stir-fry', 'Mushroom Soup', 'Stuffed Mushrooms'],
  },
  cooking_ideas: {
    chicken: [{ title: 'Simple Garlic Chicken', difficulty: 'Easy', time: '30 mins', emoji: '🍗' }],
    egg: [{ title: 'Perfect Scrambled Eggs', difficulty: 'Easy', time: '10 mins', emoji: '🍳' }],
    banana: [{ title: '2-Ingredient Banana Pancakes', difficulty: 'Easy', time: '15 mins', emoji: '🥞' }],
    spinach: [{ title: 'Garlic Sauteed Spinach', difficulty: 'Easy', time: '10 mins', emoji: '🥬' }],
    potato: [{ title: 'Crispy Smashed Potatoes', difficulty: 'Easy', time: '25 mins', emoji: '🥔' }],
    noodle: [{ title: 'Quick Stir-fried Noodles', difficulty: 'Easy', time: '15 mins', emoji: '🍜' }],
    bread: [{ title: 'Classic French Toast', difficulty: 'Easy', time: '15 mins', emoji: '🍞' }],
  },
  tips: {
    free_food: ['This item is free! Pick up only what you need so others can benefit too.'],
    for_sale: ['Great price! Confirm pickup details with the owner before heading over.'],
    borrow: ['Remember to return borrowed items on time so others can use them too.'],
    free_nonfood: ['Free items go fast — message the owner quickly to claim yours!'],
    wanted: ['If you have this item, consider helping out a neighbour!'],
  },
};

function extractKeywords(text) {
  const stop = new Set(['the', 'a', 'an', 'and', 'or', 'of', 'in', 'to', 'for', 'with', 'is', 'are']);
  return text.toLowerCase().split(/\s+/).filter((w) => w.length > 2 && !stop.has(w));
}

function findRecipes(keywords) {
  const recipes = new Set();
  for (const kw of keywords) {
    for (const [key, list] of Object.entries(FOOD_DATA.ingredients_to_recipes)) {
      if (kw.includes(key) || key.includes(kw)) list.forEach((r) => recipes.add(r));
    }
  }
  return Array.from(recipes).slice(0, 8);
}

function findCookingIdeas(keywords) {
  const ideas = [];
  for (const kw of keywords) {
    for (const [key, list] of Object.entries(FOOD_DATA.cooking_ideas)) {
      if (kw.includes(key) || key.includes(kw)) {
        list.forEach((i) => { if (!ideas.find((x) => x.title === i.title)) ideas.push(i); });
      }
    }
  }
  if (ideas.length === 0) {
    ideas.push(
      { title: 'Simple Stir-fry', difficulty: 'Easy', time: '20 mins', emoji: '🥘' },
      { title: 'Warm Soup', difficulty: 'Easy', time: '30 mins', emoji: '🍲' },
    );
  }
  return ideas.slice(0, 4);
}

const ownerSelect = `
  u.id AS owner_id,
  u.name AS owner_name,
  u.avatar AS owner_avatar,
  u.bio AS owner_bio,
  u.total_shared AS owner_total_shared,
  u.total_received AS owner_total_received,
  u.mealsaved AS owner_mealsaved,
  u.rating AS owner_rating,
  u.rating_count AS owner_rating_count
`;

router.post('/recommend', async (req, res) => {
  try {
    const { listingId, title = '', tags = [], category = '', description = '' } = req.body;
    let keywords = Array.isArray(tags) ? [...tags] : [];
    if (title) keywords.push(...extractKeywords(title));
    if (description) keywords.push(...extractKeywords(description).slice(0, 6));
    keywords = [...new Set(keywords.map(String).map((item) => item.toLowerCase()))];

    const mlData = await callPythonMl({ listingId, title, tags, category, description });
    const recipes = mlData?.recipes?.length ? mlData.recipes : findRecipes(keywords);
    const cookingIdeas = mlData?.cookingIdeas?.length
      ? mlData.cookingIdeas
      : findCookingIdeas(keywords);
    const nutritionInfo = mlData?.nutritionInfo || {};
    const matchedIngredients = mlData?.matchedIngredients || keywords.slice(0, 10);
    const tips = FOOD_DATA.tips[category] || [];

    let similarListings = [];
    if (listingId) {
      const listingRes = await query('SELECT id, category, tags FROM listings WHERE id = $1 LIMIT 1', [listingId]);
      const listing = listingRes.rows[0];
      if (listing) {
        const similarRes = await query(
          `SELECT l.*, NULL AS distance, ${ownerSelect}
           FROM listings l
           JOIN users u ON u.id = l.owner_id
           WHERE l.id <> $1
             AND l.is_available = TRUE
             AND (l.category = $2 OR l.tags && $3::text[])
           ORDER BY l.created_at DESC
           LIMIT 6`,
          [listingId, listing.category, listing.tags || []],
        );
        similarListings = similarRes.rows.map(formatListing);
      }
    }

    res.json({
      success: true,
      data: {
        recipes,
        cookingIdeas,
        nutritionInfo,
        matchedIngredients,
        tips: tips.length ? [tips[0]] : [],
        similarListings,
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/cooking-ideas', async (req, res) => {
  try {
    const { ingredients = [] } = req.body;
    res.json({
      success: true,
      data: {
        cookingIdeas: findCookingIdeas(ingredients),
        suggestedRecipes: findRecipes(ingredients),
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
