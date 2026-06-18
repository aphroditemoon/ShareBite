"""
ShareBite ML Service
Standalone Python Flask service for advanced food recommendations.
Uses TF-IDF + Cosine Similarity for content-based filtering.
Run: pip install flask scikit-learn pandas numpy && python ml_service.py
"""

from flask import Flask, request, jsonify
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
import pandas as pd
import json

app = Flask(__name__)

# ─── Indonesian Food Knowledge Base ────────────────────────────────────────

FOOD_RECIPES = [
    {"name": "Nasi Goreng Spesial", "ingredients": ["nasi", "telur", "bawang", "kecap", "ayam", "udang"],
     "tags": ["nasi", "goreng", "spesial"], "difficulty": "mudah", "time": "15 menit", "emoji": "🍳"},
    {"name": "Ayam Goreng Bumbu Kuning", "ingredients": ["ayam", "kunyit", "bawang", "kemiri", "lengkuas"],
     "tags": ["ayam", "goreng", "kuning"], "difficulty": "sedang", "time": "45 menit", "emoji": "🍗"},
    {"name": "Soto Ayam", "ingredients": ["ayam", "kunyit", "serai", "daun jeruk", "bihun"],
     "tags": ["soto", "ayam", "sup"], "difficulty": "sedang", "time": "60 menit", "emoji": "🍜"},
    {"name": "Tempe Orek Pedas", "ingredients": ["tempe", "cabai", "bawang", "kecap", "gula"],
     "tags": ["tempe", "orek", "pedas"], "difficulty": "mudah", "time": "20 menit", "emoji": "🧆"},
    {"name": "Sayur Bening Bayam", "ingredients": ["bayam", "jagung", "bawang", "garam"],
     "tags": ["bayam", "sayur", "bening"], "difficulty": "mudah", "time": "15 menit", "emoji": "🥬"},
    {"name": "Rendang Daging", "ingredients": ["daging", "santan", "cabai", "serai", "kunyit"],
     "tags": ["rendang", "daging", "padang"], "difficulty": "sulit", "time": "3 jam", "emoji": "🥩"},
    {"name": "Gado-gado", "ingredients": ["tahu", "tempe", "sayur", "kacang", "lontong"],
     "tags": ["gado", "sayuran", "kacang"], "difficulty": "sedang", "time": "30 menit", "emoji": "🥗"},
    {"name": "Mie Goreng Jawa", "ingredients": ["mie", "telur", "kol", "wortel", "bawang"],
     "tags": ["mie", "goreng", "jawa"], "difficulty": "mudah", "time": "15 menit", "emoji": "🍜"},
    {"name": "Opor Ayam", "ingredients": ["ayam", "santan", "kemiri", "kunyit", "serai"],
     "tags": ["opor", "ayam", "santan"], "difficulty": "sedang", "time": "50 menit", "emoji": "🍲"},
    {"name": "Pecel Sayur", "ingredients": ["kangkung", "kacang", "sayur", "cabai"],
     "tags": ["pecel", "sayur", "kacang"], "difficulty": "mudah", "time": "20 menit", "emoji": "🥦"},
    {"name": "Pisang Goreng", "ingredients": ["pisang", "tepung", "minyak", "gula"],
     "tags": ["pisang", "goreng", "cemilan"], "difficulty": "mudah", "time": "15 menit", "emoji": "🍌"},
    {"name": "Kolak Pisang", "ingredients": ["pisang", "santan", "gula merah", "pandan"],
     "tags": ["kolak", "pisang", "santan"], "difficulty": "mudah", "time": "20 menit", "emoji": "🍮"},
    {"name": "Tumis Kangkung", "ingredients": ["kangkung", "bawang", "cabai", "terasi"],
     "tags": ["tumis", "kangkung", "sayur"], "difficulty": "mudah", "time": "10 menit", "emoji": "🥬"},
    {"name": "Perkedel Kentang", "ingredients": ["kentang", "daging", "telur", "bawang"],
     "tags": ["perkedel", "kentang", "goreng"], "difficulty": "sedang", "time": "30 menit", "emoji": "🫘"},
    {"name": "Bakso Kuah", "ingredients": ["daging", "tepung", "bawang", "merica"],
     "tags": ["bakso", "kuah", "daging"], "difficulty": "sulit", "time": "90 menit", "emoji": "🍡"},
    {"name": "Semur Tahu Telur", "ingredients": ["tahu", "telur", "kecap", "bawang", "cengkeh"],
     "tags": ["semur", "tahu", "telur"], "difficulty": "mudah", "time": "25 menit", "emoji": "🥚"},
    {"name": "Capcay Goreng", "ingredients": ["wortel", "kol", "brokoli", "bakso", "saos tiram"],
     "tags": ["capcay", "sayur", "goreng"], "difficulty": "mudah", "time": "20 menit", "emoji": "🥡"},
    {"name": "Nasi Uduk", "ingredients": ["beras", "santan", "serai", "daun salam"],
     "tags": ["nasi", "uduk", "santan"], "difficulty": "mudah", "time": "30 menit", "emoji": "🍚"},
    {"name": "Ayam Geprek", "ingredients": ["ayam", "tepung", "cabai", "bawang", "minyak"],
     "tags": ["ayam", "geprek", "pedas"], "difficulty": "mudah", "time": "30 menit", "emoji": "🍗"},
    {"name": "Es Buah", "ingredients": ["semangka", "melon", "nata de coco", "sirup", "es"],
     "tags": ["es", "buah", "minuman"], "difficulty": "mudah", "time": "10 menit", "emoji": "🍉"},
]

# Build TF-IDF model
def build_tfidf_model():
    docs = []
    for r in FOOD_RECIPES:
        text = " ".join(r["ingredients"] + r["tags"] + [r["name"].lower()])
        docs.append(text)
    
    vectorizer = TfidfVectorizer(analyzer='word', ngram_range=(1, 2), min_df=1)
    tfidf_matrix = vectorizer.fit_transform(docs)
    return vectorizer, tfidf_matrix

vectorizer, tfidf_matrix = build_tfidf_model()

def find_recipes_ml(keywords: list, top_n: int = 6) -> list:
    """Use TF-IDF cosine similarity to find matching recipes."""
    if not keywords:
        return FOOD_RECIPES[:top_n]
    
    query = " ".join(keywords).lower()
    query_vec = vectorizer.transform([query])
    similarities = cosine_similarity(query_vec, tfidf_matrix).flatten()
    
    top_indices = similarities.argsort()[::-1][:top_n]
    results = []
    for idx in top_indices:
        if similarities[idx] > 0:
            recipe = FOOD_RECIPES[idx].copy()
            recipe["similarity_score"] = float(similarities[idx])
            results.append(recipe)
    
    if not results:
        return FOOD_RECIPES[:3]
    return results

def extract_keywords(text: str) -> list:
    """Extract Indonesian food-related keywords from text."""
    stop_words = {'yang', 'dan', 'di', 'ke', 'dari', 'ini', 'itu', 'dengan', 'untuk', 'ada', 'sudah', 'bisa'}
    words = text.lower().split()
    return [w for w in words if len(w) > 2 and w not in stop_words]

# ─── Nutrition Database ─────────────────────────────────────────────────────

NUTRITION_DB = {
    "ayam": {"protein": "27g/100g", "kalori": "165 kcal", "lemak": "3.6g", "vitamin": "B12, B6"},
    "tempe": {"protein": "19g/100g", "kalori": "193 kcal", "serat": "tinggi", "probiotik": "ya"},
    "tahu": {"protein": "8g/100g", "kalori": "76 kcal", "kalsium": "tinggi"},
    "bayam": {"vitamin": "A, C, K", "kalori": "23 kcal", "zat_besi": "2.7mg/100g"},
    "wortel": {"vitamin": "A (beta-karoten)", "kalori": "41 kcal", "serat": "2.8g"},
    "pisang": {"kalium": "358mg/100g", "karbohidrat": "23g", "vitamin": "B6"},
    "telur": {"protein": "13g/100g", "kalori": "155 kcal", "kolin": "tinggi"},
    "ikan": {"protein": "20g/100g", "omega3": "tinggi", "kalori": "beragam"},
    "kentang": {"karbohidrat": "17g/100g", "kalori": "77 kcal", "kalium": "tinggi"},
    "beras": {"karbohidrat": "28g/100g", "kalori": "130 kcal", "gluten": "bebas"},
}

# ─── Routes ─────────────────────────────────────────────────────────────────

@app.route('/health')
def health():
    return jsonify({"status": "ok", "service": "ShareBite ML"})

@app.route('/recommend', methods=['POST'])
def recommend():
    data = request.json or {}
    title = data.get('title', '')
    tags = data.get('tags', [])
    description = data.get('description', '')
    category = data.get('category', '')
    
    # Build keyword list
    keywords = list(tags)
    if title:
        keywords.extend(extract_keywords(title))
    if description:
        keywords.extend(extract_keywords(description)[:8])
    keywords = list(set(keywords))
    
    # Get ML-based recipe recommendations
    matched_recipes = find_recipes_ml(keywords, top_n=8)
    
    # Get nutrition info
    nutrition = {}
    for kw in keywords:
        if kw in NUTRITION_DB:
            nutrition[kw] = NUTRITION_DB[kw]
    
    # Generate cooking ideas
    cooking_ideas = []
    for recipe in matched_recipes[:4]:
        cooking_ideas.append({
            "title": recipe["name"],
            "difficulty": recipe["difficulty"],
            "time": recipe["time"],
            "emoji": recipe["emoji"],
            "score": recipe.get("similarity_score", 0)
        })
    
    return jsonify({
        "success": True,
        "data": {
            "recipes": [r["name"] for r in matched_recipes],
            "recipeDetails": matched_recipes,
            "cookingIdeas": cooking_ideas,
            "nutritionInfo": nutrition,
            "matchedIngredients": keywords[:10],
        }
    })

@app.route('/cooking-ideas', methods=['POST'])
def cooking_ideas():
    data = request.json or {}
    ingredients = data.get('ingredients', [])
    
    matched = find_recipes_ml(ingredients, top_n=6)
    ideas = [{"title": r["name"], "difficulty": r["difficulty"],
               "time": r["time"], "emoji": r["emoji"]} for r in matched]
    
    return jsonify({
        "success": True,
        "data": {
            "cookingIdeas": ideas,
            "suggestedRecipes": [r["name"] for r in matched]
        }
    })

@app.route('/nutrition', methods=['POST'])
def nutrition():
    data = request.json or {}
    ingredients = data.get('ingredients', [])
    result = {ing: NUTRITION_DB.get(ing, {}) for ing in ingredients if ing in NUTRITION_DB}
    return jsonify({"success": True, "data": result})

if __name__ == '__main__':
    print("🧠 ShareBite ML Service starting on port 5001...")
    app.run(host='0.0.0.0', port=5001, debug=False)
