from PIL import Image
import os

# Configuration
INPUT_FOLDER = "./"  # Replace with your folder path
OUTPUT_FOLDER = os.path.join(INPUT_FOLDER, "resized")
MAX_WIDTH = 1920
JPG_QUALITY = 85
SUPPORTED_EXTENSIONS = (".png", ".jpg", ".jpeg", ".gif", ".bmp")

def resize_images():
    # Create output folder if it doesn't exist
    if not os.path.exists(OUTPUT_FOLDER):
        os.makedirs(OUTPUT_FOLDER)

    # Process each file in the input folder
    for filename in os.listdir(INPUT_FOLDER):
        if filename.lower().endswith(SUPPORTED_EXTENSIONS):
            input_path = os.path.join(INPUT_FOLDER, filename)
            output_filename = f"{os.path.splitext(filename)[0]}.jpg"
            output_path = os.path.join(OUTPUT_FOLDER, output_filename)

            try:
                with Image.open(input_path) as img:
                    # Handle transparent images by adding white background
                    if img.mode in ('RGBA', 'LA'):
                        background = Image.new('RGB', img.size, (255, 255, 255))
                        background.paste(img, mask=img.split()[-1])
                        img = background
                    else:
                        img = img.convert('RGB')

                    # Resize if needed
                    if img.width > MAX_WIDTH:
                        ratio = MAX_WIDTH / img.width
                        new_height = int(img.height * ratio)
                        img = img.resize((MAX_WIDTH, new_height), Image.LANCZOS)

                    # Save as JPG
                    img.save(output_path, "JPEG", quality=JPG_QUALITY)
                    print(f"Processed: {filename} -> {output_filename}")

            except Exception as e:
                print(f"Error processing {filename}: {str(e)}")

if __name__ == "__main__":
    resize_images()