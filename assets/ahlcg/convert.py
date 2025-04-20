import os
from PIL import Image
import argparse

def convert_and_replace(input_folder, quality=85):
    converted = 0
    errors = 0

    for filename in os.listdir(input_folder):
        if filename.lower().endswith('.png'):
            png_path = os.path.join(input_folder, filename)
            base_name = os.path.splitext(filename)[0]
            jpg_path = os.path.join(input_folder, f"{base_name}.jpg")

            try:
                # Open and convert image
                with Image.open(png_path) as img:
                    rgb_img = img.convert('RGB')
                    rgb_img.save(jpg_path, 'JPEG', quality=quality)
                
                # Remove original PNG only after successful conversion
                os.remove(png_path)
                print(f"Replaced: {filename} -> {base_name}.jpg")
                converted += 1

            except Exception as e:
                print(f"Error processing {filename}: {str(e)}")
                errors += 1

    print(f"\nComplete: {converted} files converted, {errors} errors")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='⚠️ Replace PNG files with JPG versions in-place ⚠️',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    
    parser.add_argument('-i', '--input', default='.',
                      help='Folder containing PNG files')
    parser.add_argument('-q', '--quality', type=int, default=85,
                      help='JPEG quality (1-100)')
    parser.add_argument('--force', action='store_true',
                      help='Skip confirmation prompt')

    args = parser.parse_args()

    # Safety confirmation
    if not args.force:
        print("\n⚠️ WARNING: This will PERMANENTLY:")
        print("- Convert PNG files to JPG")
        print("- Delete original PNG files")
        print("- Overwrite existing JPG files with same names\n")
        
        confirm = input("Continue? (y/n): ").strip().lower()
        if confirm != 'y':
            print("Conversion canceled")
            exit()

    convert_and_replace(args.input, args.quality)