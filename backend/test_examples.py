#!/usr/bin/env python3
"""
Test Examples for Anona Backend AI Pipeline

Run these examples after starting the server:
    python main.py

Then in another terminal:
    python test_examples.py
"""

import requests
import json
from typing import Dict, Any

BASE_URL = "http://localhost:8000"


def print_response(title: str, response: requests.Response):
    """Pretty print API response."""
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")
    try:
        data = response.json()
        print(json.dumps(data, indent=2))
    except:
        print(response.text)
    print(f"Status: {response.status_code}")


def test_health():
    """Test health check endpoint."""
    response = requests.get(f"{BASE_URL}/health")
    print_response("Health Check", response)
    return response.status_code == 200


def test_daily_digest_tech():
    """Test daily digest with technology topic."""
    payload = {
        "topics": ["technology", "artificial intelligence"],
        "tone": "analyst",
        "country": "us",
        "limit": 2
    }
    response = requests.post(
        f"{BASE_URL}/get-daily-digest",
        json=payload
    )
    print_response("Daily Digest - Technology (Professional Tone)", response)
    return response.status_code == 200


def test_daily_digest_casual():
    """Test daily digest with casual tone."""
    payload = {
        "topics": ["business", "finance"],
        "tone": "Casual",
        "country": "us",
        "limit": 2
    }
    response = requests.post(
        f"{BASE_URL}/get-daily-digest",
        json=payload
    )
    print_response("Daily Digest - Business (Casual Tone)", response)
    return response.status_code == 200


def test_daily_digest_academic():
    """Test daily digest with academic tone."""
    payload = {
        "topics": ["science", "research"],
        "tone": "Academic",
        "country": "us",
        "limit": 1
    }
    response = requests.post(
        f"{BASE_URL}/get-daily-digest",
        json=payload
    )
    print_response("Daily Digest - Science (Academic Tone)", response)
    return response.status_code == 200


def test_discovery_news():
    """Test discovery news endpoint."""
    response = requests.get(
        f"{BASE_URL}/get-discovery-news",
        params={
            "tone": "Friendly",
            "limit": 2,
            "country": "us"
        }
    )
    print_response("Discovery News (Friendly Tone)", response)
    return response.status_code == 200


def test_deep_dive():
    """Test deep dive with a real article URL."""
    # First, get a URL from daily digest
    print("\n[Getting article URL from Daily Digest...]")
    digest_response = requests.post(
        f"{BASE_URL}/get-daily-digest",
        json={
            "topics": ["technology"],
            "tone": "analyst",
            "limit": 1
        }
    )
    
    if digest_response.status_code != 200:
        print("Failed to get article URL")
        return False
    
    data = digest_response.json()
    if not data.get("articles"):
        print("No articles found")
        return False
    
    url = data["articles"][0]["url"]
    print(f"[Using article URL: {url}]")
    
    # Now test deep dive
    response = requests.get(
        f"{BASE_URL}/get-deep-dive",
        params={"url": url}
    )
    print_response("Deep Dive Analysis", response)
    return response.status_code == 200


def test_invalid_topic():
    """Test with empty topics (should fail)."""
    payload = {
        "topics": [],
        "tone": "analyst"
    }
    response = requests.post(
        f"{BASE_URL}/get-daily-digest",
        json=payload
    )
    print_response("Error Test - Empty Topics", response)
    return response.status_code == 400


def test_invalid_url():
    """Test deep dive with invalid URL."""
    response = requests.get(
        f"{BASE_URL}/get-deep-dive",
        params={"url": "https://invalid-url-that-cannot-be-scraped-12345.xyz"}
    )
    print_response("Error Test - Invalid URL", response)
    return response.status_code == 400


def run_all_tests():
    """Run all test examples."""
    print("\n")
    print("╔" + "=" * 58 + "╗")
    print("║" + " " * 58 + "║")
    print("║" + "  Anona Backend - API Test Examples".center(58) + "║")
    print("║" + " " * 58 + "║")
    print("╚" + "=" * 58 + "╝")
    
    tests = [
        ("Health Check", test_health),
        ("Daily Digest - Technology", test_daily_digest_tech),
        ("Daily Digest - Casual Tone", test_daily_digest_casual),
        ("Daily Digest - Academic Tone", test_daily_digest_academic),
        ("Discovery News", test_discovery_news),
        ("Deep Dive Analysis", test_deep_dive),
        ("Error Test - Empty Topics", test_invalid_topic),
        ("Error Test - Invalid URL", test_invalid_url),
    ]
    
    results = []
    for name, test_func in tests:
        try:
            success = test_func()
            results.append((name, "✅ PASS" if success else "❌ FAIL"))
        except Exception as e:
            print(f"\n❌ ERROR in {name}: {str(e)}")
            results.append((name, f"❌ ERROR: {str(e)[:40]}"))
    
    # Summary
    print("\n\n")
    print("╔" + "=" * 58 + "╗")
    print("║" + " " * 58 + "║")
    print("║" + "  TEST SUMMARY".center(58) + "║")
    print("║" + " " * 58 + "║")
    for name, result in results:
        status = "✅" if "PASS" in result else "❌"
        print(f"║ {status} {name:<50} {result[-6:]:>6} ║")
    print("║" + " " * 58 + "║")
    print("╚" + "=" * 58 + "╝")
    
    passed = sum(1 for _, result in results if "PASS" in result)
    print(f"\n📊 Results: {passed}/{len(results)} tests passed")


if __name__ == "__main__":
    try:
        # Check if server is running
        requests.get(f"{BASE_URL}/health", timeout=2)
        run_all_tests()
    except requests.exceptions.ConnectionError:
        print("❌ Error: Cannot connect to server at http://localhost:8000")
        print("   Please start the server first: python main.py")
    except Exception as e:
        print(f"❌ Error: {e}")
