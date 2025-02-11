import glob
import os

WORD_DIR = "wordlist/final"
PATTERNS = [
    # English words
    "english-words.10", "english-words.20", "english-words.35",
    "english-words.40", "english-words.50", "english-words.55",
    "english-words.60", "english-words.70", "english-words.80",
    "english-words.95",
    
    # American words
    "american-words.10", "american-words.20", "american-words.35",
    "american-words.40", "american-words.50", "american-words.55", 
    "american-words.60", "american-words.70", "american-words.80",
    "american-words.95",
    
    # Abbreviations
    "american-abbreviations.70", "american-abbreviations.95",
    "english-abbreviations.70", "english-abbreviations.95",
    
    # Proper names
    "american-proper-names.50", "american-proper-names.80",
    "american-proper-names.95", "english-proper-names.50",
    
    # Upper case
    "american-upper.50", "american-upper.60", "american-upper.70",
    "american-upper.80", "american-upper.95",
    
    # Special
    "special-hacker.50", "special-roman-numerals.35"
]

def process_files():
    all_words = set()
    
    # Process each explicit pattern
    for pattern in PATTERNS:
        full_path = os.path.join(WORD_DIR, pattern)
        if not os.path.exists(full_path):
            print(f"Warning: Missing file {pattern}")
            continue
            
        with open(full_path, "r") as f:
            print(f"Processing {pattern}")
            for line in f:
                word = line.strip().lower()
                if word:
                    all_words.add(word)
    
    # For human-readable version in project root
    with open("combined-readable.txt", "w") as f:
        f.write("\n".join(sorted(all_words)))
    
    # Binary version in project root
    with open("combined.bin", "wb") as f:
        f.write(b"\x00".join(word.encode('utf-8') for word in sorted(all_words)))
    
    print(f"Processed {len(PATTERNS)} files")
    print(f"Unique words: {len(all_words)}")

if __name__ == "__main__":
    process_files()