from PIL import Image
import os

def add_padding(img_path, output_path, padding_percent=0.3):
    img = Image.open(img_path).convert("RGBA")
    width, height = img.size
    
    # Calculate new size with padding
    new_width = int(width * (1 + padding_percent * 2))
    new_height = int(height * (1 + padding_percent * 2))
    
    # Create a new transparent image
    new_img = Image.new("RGBA", (new_width, new_height), (0, 0, 0, 0))
    
    # Paste original image in center
    offset = (int(width * padding_percent), int(height * padding_percent))
    new_img.paste(img, offset, img)
    
    new_img.save(output_path)
    print(f"Saved padded logo to {output_path}")

if __name__ == "__main__":
    add_padding("../assets/icon.png", "../assets/splash_logo.png")
