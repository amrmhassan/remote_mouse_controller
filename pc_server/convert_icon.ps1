# PowerShell script to convert PNG to ICO
Add-Type -AssemblyName System.Drawing

try {
    # Load the PNG image
    $pngPath = "e:\Flutter\test\remote_mouse_controller\pc_server\windows\runner\resources\temp_icon.png"
    $icoPath = "e:\Flutter\test\remote_mouse_controller\pc_server\windows\runner\resources\app_icon_new.ico"
    
    Write-Host "Loading PNG image from: $pngPath"
    $bitmap = [System.Drawing.Bitmap]::new($pngPath)
    
    # Resize to standard icon size (32x32)
    $iconSize = 32
    $resizedBitmap = [System.Drawing.Bitmap]::new($iconSize, $iconSize)
    $graphics = [System.Drawing.Graphics]::FromImage($resizedBitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($bitmap, 0, 0, $iconSize, $iconSize)
    
    # Convert to icon
    $hIcon = $resizedBitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)
    
    Write-Host "Saving ICO file to: $icoPath"
    $fileStream = [System.IO.FileStream]::new($icoPath, [System.IO.FileMode]::Create)
    $icon.Save($fileStream)
    $fileStream.Close()
    
    Write-Host "Icon conversion completed successfully!"
    
    # Cleanup
    $bitmap.Dispose()
    $resizedBitmap.Dispose()
    $graphics.Dispose()
    $icon.Dispose()
    
} catch {
    Write-Host "Error converting icon: $_"
}
