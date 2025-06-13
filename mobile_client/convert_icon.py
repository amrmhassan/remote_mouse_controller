#!/usr/bin/env python3
"""
Convert SVG icon to PNG for Flutter launcher icons
"""
import subprocess
import sys
import os

def convert_svg_to_png():
    svg_path = "assets/icons/app_icon_new.svg"
    png_path = "assets/icons/app_icon.png"
    
    # Try using Inkscape if available
    try:
        subprocess.run([
            "inkscape", 
            "--export-type=png", 
            "--export-width=1024", 
            "--export-height=1024",
            f"--export-filename={png_path}",
            svg_path
        ], check=True)
        print(f"Successfully converted {svg_path} to {png_path}")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Inkscape not found, trying other methods...")
    
    # Try using ImageMagick
    try:
        subprocess.run([
            "magick", 
            "-background", "none",
            "-size", "1024x1024",
            svg_path, 
            png_path
        ], check=True)
        print(f"Successfully converted {svg_path} to {png_path}")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("ImageMagick not found...")
    
    # Try using wand (Python ImageMagick binding)
    try:
        from wand.image import Image
        with Image(filename=svg_path) as img:
            img.format = 'png'
            img.resize(1024, 1024)
            img.save(filename=png_path)
        print(f"Successfully converted {svg_path} to {png_path}")
        return True
    except ImportError:
        print("Wand library not available...")
    
    # Try using cairosvg
    try:
        import cairosvg
        cairosvg.svg2png(url=svg_path, write_to=png_path, output_width=1024, output_height=1024)
        print(f"Successfully converted {svg_path} to {png_path}")
        return True
    except ImportError:
        print("cairosvg library not available...")
    
    return False

if __name__ == "__main__":
    if not convert_svg_to_png():
        print("Could not convert SVG to PNG. Please install one of:")
        print("- Inkscape")
        print("- ImageMagick")
        print("- Python libraries: wand or cairosvg")
        sys.exit(1)
