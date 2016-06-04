import Foundation
import UIKit

/**
 Simple processor that manipulates pixels within the image to manipulate the output
 The interface is accessible via the public exposed commands
 **/
public struct ImageProcessor {
    var beforeImage:UIImage
    var image:UIImage
    let originalImage:UIImage
    
    var rgbaImage:RGBAImage
    
    var totalCalculated:Bool
    var redTotal:Int
    var greenTotal:Int
    var blueTotal:Int
    
    var averageCalculated:Bool
    var redAverage:UInt8
    var greenAverage:UInt8
    var blueAverage:UInt8
    
    public init(givenImage:UIImage) {
        self.originalImage = givenImage
        beforeImage = givenImage
        image = givenImage
        rgbaImage = RGBAImage(image: image)!
        
        totalCalculated = false
        redTotal = 0
        greenTotal = 0
        blueTotal = 0
        
        averageCalculated = false
        redAverage = 0
        greenAverage = 0
        blueAverage = 0
    }
    
    
    
    // -- Utils --
    
    mutating func calcTotalColors(rgbaImage: RGBAImage, cache:Bool=true) {
        if (cache && totalCalculated) {
            return
        }
        
        redTotal = 0
        greenTotal = 0
        blueTotal = 0
        
        for y in 0..<rgbaImage.height {
            for x in 0..<rgbaImage.width {
                let i = (y * rgbaImage.width) + x;
                let pixel = rgbaImage.pixels[i];
                
                redTotal += Int(pixel.red)
                greenTotal += Int(pixel.green)
                blueTotal += Int(pixel.blue)
            }
        }
        totalCalculated = true
    }
    
    mutating func calcAverageColors(rgbaImage: RGBAImage, cache:Bool=true) {
        if (cache && averageCalculated) {
            return
        }
        
        let totalPixels = rgbaImage.width * rgbaImage.height
        
        redAverage = UInt8(max(0, min(255, redTotal / totalPixels)))
        greenAverage = UInt8(max(0, min(255, greenTotal / totalPixels)))
        blueAverage = UInt8(max(0, min(255, blueTotal / totalPixels)))
        
        averageCalculated = true
    }
    
    // Heart of the basic pixel manipulations, takes a processor which should return the new pixel
    func pixelImageProcessor(rgbaImage: RGBAImage, processor: (pixel:Pixel) -> Pixel) -> RGBAImage {
        var processedRgbaImage = rgbaImage
        for y in 0..<processedRgbaImage.height {
            for x in 0..<processedRgbaImage.width {
                let i = (y * processedRgbaImage.width) + x;
                let pixel = processedRgbaImage.pixels[i]
                let processedPixel = processor(pixel: pixel)
                
                processedRgbaImage.pixels[i] = processedPixel
            }
        }
        return processedRgbaImage
    }
    
    // Calculates saturation relative to the percantage given
    func getSaturationAlternation(color:UInt8, alteration:Int) -> UInt8 {
        var processedColor:UInt8 = color
        let reducedAlteration = Float(max(-100, min(100, alteration)))
        
        // take color and manipulate it based on its current position, any change up or down is based on percentage
        if (reducedAlteration > 0) {
            let onePercent = (255 - Float(processedColor)) / 100
            let calcPerc = UInt8(max(0, min(255, reducedAlteration * onePercent)))
            processedColor = UInt8(max(0, min(255, color + calcPerc)))
        } else if (reducedAlteration < 0) {
            let onePercent = Float(processedColor) / 100
            let calcPerc = UInt8(max(0, min(255, (-1  * reducedAlteration) * onePercent)))
            processedColor = UInt8(max(0, min(255, color - calcPerc)))
        }
        
        return processedColor
    }
    
    // Calculates contrast based on the alteration and average given
    func getContrastAlteration(color:UInt8, average:UInt8, alteration:Int) -> UInt8 {
        var processedColor:UInt8 = color
        let reducedAlteration = Float(max(-100, min(100, alteration)))
        let maxContrast = 10
        let colorDelta = (Int(color) - Int(average)) * maxContrast
        let onePercent = Float(colorDelta) / 100
        let calcPerc = reducedAlteration * onePercent
        
        if (reducedAlteration > 0) {
            let calcPerc = reducedAlteration * onePercent
            processedColor = UInt8(max(0, min(255, Float(color) + calcPerc)))
        } else if (reducedAlteration < 0) {
            let calcPerc = (-1 * reducedAlteration) * onePercent
            processedColor = UInt8(max(0, min(255, Float(color) - calcPerc)))
        }
        processedColor = UInt8(max(0, min(255, Float(color) + calcPerc)))
        
        return processedColor
    }
    
    // Converts alteration into a float between 0 and 1
    func getReducedAlteration(alteration:UInt8) -> Float {
        return Float(min(1, max(0, Float(alteration) / 100.0)))
    }
    
    // Calculates the color difference relative to the percentage given
    func getColorDifference(color:UInt8, newColor:UInt8, alteration:UInt8) -> Int {
        let reducedAlteration = getReducedAlteration(alteration)
        return Int((Float(newColor) - Float(color)) * reducedAlteration)
    }
    
    // Calculates the new color based on the alteration given
    func getNewColor(color:UInt8, newColor:UInt8, alteration:UInt8=100) -> UInt8 {
        return UInt8(max(0, min(255,
            Int(color) +
                getColorDifference(color, newColor: newColor, alteration: alteration)
            )))
    }
    
    // Calculates and returns inverted color
    func getInvertedColor(color:UInt8) -> UInt8 {
        return max(0, (255 - color))
    }
    
    func convolutionPixelImageProcessor(rgbaImage:RGBAImage, weights:[Float]) -> RGBAImage {
        var processedRgbaImage = rgbaImage
        
        let side = Int(sqrt(Float(weights.count)))
        let halfSide = Int(side / 2)
        
        let sw = processedRgbaImage.width
        let sh = processedRgbaImage.height
        
        for y in 0..<processedRgbaImage.height {
            for x in 0..<processedRgbaImage.width {
                let dstOff = (y*sw+x)
                var red:Float = 0
                var green:Float = 0
                var blue:Float = 0
                var processedPixel = processedRgbaImage.pixels[dstOff]
                for cy in 0..<side {
                    for cx in 0..<side {
                        let scy = y + cy - halfSide
                        let scx = x + cx - halfSide
                        if (scy >= 0 && scy < sh && scx >= 0 && scx < processedRgbaImage.width) {
                            let srcOff = (scy*sw+scx)
                            let wt = weights[cy*side+cx]
                            let pixel = rgbaImage.pixels[srcOff]
                            
                            red += Float(pixel.red) * wt
                            green += Float(pixel.green) * wt
                            blue += Float(pixel.blue) * wt
                        }
                    }
                }
                processedPixel.red = UInt8(max(0, min(255,
                    red
                    )))
                processedPixel.green = UInt8(max(0, min(255,
                    green
                    )))
                processedPixel.blue = UInt8(max(0, min(255,
                    blue
                    )))
            }
        }
        return processedRgbaImage
    }
    
    
    
    // -- Processors --
    
    func saturationPixelProcessor(pixel:Pixel, redAlteration:Int=0, blueAlteration:Int=0, greenAlteration:Int=0) -> Pixel {
        var processedPixel = pixel
        
        processedPixel.red = getSaturationAlternation(processedPixel.red, alteration: redAlteration)
        processedPixel.blue = getSaturationAlternation(processedPixel.blue, alteration: blueAlteration)
        processedPixel.green = getSaturationAlternation(processedPixel.green, alteration: greenAlteration)
        
        return processedPixel
    }
    
    func desaturatePixelProcessor(pixel:Pixel, alteration:UInt8, type:String="average") -> Pixel {
        var processedPixel = pixel
        
        switch type {
        case "blue":
            let newColor = processedPixel.blue
            processedPixel.red = getNewColor(processedPixel.red, newColor: newColor, alteration: alteration)
            processedPixel.green = getNewColor(processedPixel.green, newColor: newColor, alteration: alteration)
        case "green":
            let newColor = processedPixel.green
            processedPixel.red = getNewColor(processedPixel.red, newColor: newColor, alteration: alteration)
            processedPixel.blue = getNewColor(processedPixel.blue, newColor: newColor, alteration: alteration)
        case "red":
            let newColor = processedPixel.red
            processedPixel.blue = getNewColor(processedPixel.blue, newColor: newColor, alteration: alteration)
            processedPixel.green = getNewColor(processedPixel.green, newColor: newColor, alteration: alteration)
        default:
            let newColor = UInt8(
                (
                    Int(processedPixel.red) +
                        Int(processedPixel.blue) +
                        Int(processedPixel.green)
                    ) / 3
            )
            
            // calculate pixel by taking amount, check the difference and take a percentage of that difference
            processedPixel.red = getNewColor(processedPixel.red, newColor: newColor, alteration: alteration)
            processedPixel.blue = getNewColor(processedPixel.blue, newColor: newColor, alteration: alteration)
            processedPixel.green = getNewColor(processedPixel.green, newColor: newColor, alteration: alteration)
        }
        
        return processedPixel
    }
    
    func invertPixelProcessor(pixel:Pixel, alteration:UInt8=100) -> Pixel {
        var processedPixel = pixel
        
        processedPixel.red = getNewColor(processedPixel.red, newColor: getInvertedColor(processedPixel.red), alteration: alteration)
        processedPixel.blue = getNewColor(processedPixel.blue, newColor: getInvertedColor(processedPixel.blue), alteration: alteration)
        processedPixel.green = getNewColor(processedPixel.green, newColor: getInvertedColor(processedPixel.green), alteration: alteration)
        
        return processedPixel
    }
    
    func outlinePixelProcessor(pixel:Pixel, alteration:UInt8=100, allowWhite:Bool=true, allowGrays:Bool=false) -> Pixel {
        var processedPixel = pixel
        
        let threshold = Int(765 * getReducedAlteration(alteration))
        
        let totalColor = Int(processedPixel.red) + Int(processedPixel.blue) + Int(processedPixel.green)
        
        if (totalColor < threshold) {
            let black = allowGrays ? [processedPixel.red, processedPixel.green, processedPixel.blue].sort({ $0 > $1 })[0] : 0
            
            processedPixel.red = black
            processedPixel.green = black
            processedPixel.blue = black
        } else if (allowWhite) {
            processedPixel.red = 255
            processedPixel.green = 255
            processedPixel.blue = 255
        }
        
        return processedPixel
    }
    
    func contrastPixelProcessor(pixel:Pixel, redAverage:UInt8, greenAverage:UInt8, blueAverage:UInt8, alteration:Int=100) -> Pixel {
        var processedPixel = pixel
        
        processedPixel.red = getContrastAlteration(processedPixel.red, average: redAverage, alteration: alteration)
        processedPixel.green = getContrastAlteration(processedPixel.green, average: greenAverage, alteration: alteration)
        processedPixel.blue = getContrastAlteration(processedPixel.blue, average: blueAverage, alteration: alteration)
        
        return processedPixel
    }
    
    
    
    // -- Methods --
    
    /**
     Removes color from a image
     
     - Parameter alteration: A percentage 0-100 that indicates how much color needs to be removed
     - Parameter type: A string representing how to calculate the desaturation, e.g. red, green, blue, average
     
     - Returns: The adjusted image
     */
    public mutating func desaturate(alteration:UInt8?=100, type:String?="average") -> UIImage {
        func desaturationProcessor(pixel:Pixel) -> Pixel {
            return desaturatePixelProcessor(pixel, alteration: alteration!, type: type!)
        }
        rgbaImage = pixelImageProcessor(rgbaImage, processor: desaturationProcessor)
        beforeImage = image
        image = rgbaImage.toUIImage()!
        return image
    }
    
    /**
     Changes color in a image
     
     - Parameter redAlteration: A percentage -100-100 that indicates how much red needs to be added or subtracted
     - Parameter blueAlteration: A percentage -100-100 that indicates how much blue needs to be added or subtracted
     - Parameter greenAlteration: A percentage -100-100 that indicates how much green needs to be added or subtracted

     - Returns: The adjusted image
     */
    public mutating func saturate(redAlteration:Int?=25, blueAlteration:Int?=0, greenAlteration:Int?=50) -> UIImage {
        func saturationProcessor(pixel:Pixel) -> Pixel {
            return saturationPixelProcessor(pixel, redAlteration: redAlteration!, blueAlteration: blueAlteration!, greenAlteration: greenAlteration!)
        }
        rgbaImage = pixelImageProcessor(rgbaImage, processor: saturationProcessor)
        beforeImage = image
        image = rgbaImage.toUIImage()!
        return image
    }
    
    /**
     Flips the color in a image
     
     - Parameter alteration: A percentage 0-100 that indicates how much inversion is needed
     - Returns: The adjusted image
     */
    public mutating func invert(alteration:UInt8?=100) -> UIImage {
        func invertProcessor(pixel:Pixel) -> Pixel {
            return invertPixelProcessor(pixel, alteration: alteration!)
        }
        rgbaImage = pixelImageProcessor(rgbaImage, processor: invertProcessor)
        beforeImage = image
        image = rgbaImage.toUIImage()!
        return image
    }
    
    /**
     Outlines a image in hard colors (black/white)
     
     - Parameter alteration: A percentage 0-100 that indicates how much outline is needed
     - Parameter allowWhite: A boolean if true white should be used, else it uses the original color if not black
     - Parameter allowGrays: A boolean indicating if true black should be used, else it uses graytones for the black
     - Returns: The adjusted image
     */
    public mutating func outline(alteration:UInt8?=50, allowWhite:Bool?=true, allowGrays:Bool?=false) -> UIImage {
        func outlineProcessor(pixel:Pixel) -> Pixel {
            return outlinePixelProcessor(pixel, alteration: alteration!, allowWhite: allowWhite!, allowGrays: allowGrays!)
        }
        rgbaImage = pixelImageProcessor(rgbaImage, processor: outlineProcessor)
        beforeImage = image
        image = rgbaImage.toUIImage()!
        return image
    }
    
    /**
     Enhances colors in the image
     
     - Parameter alteration: A percentage 0-100 that indicates how much contrast is needed
     - Returns: The adjusted image
     */
    public mutating func contrast(alteration:Int?=20) -> UIImage {
        calcTotalColors(rgbaImage, cache: false)
        calcAverageColors(rgbaImage, cache: false)
        
        func contrastProcessor(pixel:Pixel) -> Pixel {
            return contrastPixelProcessor(pixel, redAverage: redAverage, greenAverage: greenAverage, blueAverage: blueAverage, alteration: alteration!)
        }
        rgbaImage = pixelImageProcessor(rgbaImage, processor: contrastProcessor)
        beforeImage = image
        image = rgbaImage.toUIImage()!
        return image
    }
    
    /**
     Increases brightness in the image
     
     - Parameter alteration: A percentage 0-100 that indicates how much brightness is needed
     - Returns: The adjusted image
     */
    public mutating func brightness(alteration:Int?=20) -> UIImage {
        func brightnessProcessor(pixel:Pixel) -> Pixel {
            return saturationPixelProcessor(pixel, redAlteration: alteration!, greenAlteration: alteration!, blueAlteration: alteration!)
        }
        rgbaImage = pixelImageProcessor(rgbaImage, processor: brightnessProcessor)
        beforeImage = image
        image = rgbaImage.toUIImage()!
        return image
    }
    
    /*public mutating func sharpen(alteration:UInt8?=100) -> UIImage {
     let reducedAlteration = getReducedAlteration(alteration!)
     let lo:Float = -5 * reducedAlteration
     let mi:Float = 0
     let hi:Float = 15 * reducedAlteration
     rgbaImage = convolutionPixelImageProcessor(rgbaImage, weights: [
     mi,     lo,     mi,
     lo,     hi,     lo,
     mi,     lo,     mi
     ])
     beforeImage = image
     image = rgbaImage.toUIImage()!
     return image
     }
     
     public mutating func blur(alteration:UInt8?=100) -> UIImage {
     let reducedAlteration = getReducedAlteration(alteration!)
     let blur:Float = 0.1 * reducedAlteration
     rgbaImage = convolutionPixelImageProcessor(rgbaImage, weights: [
     blur,     blur,     blur,
     blur,     blur,     blur,
     blur,     blur,     blur
     ])
     beforeImage = image
     image = rgbaImage.toUIImage()!
     return image
     }*/
    
    /**
     Creates a instagram like preset called 'blue haze'
     
     - Parameter alteration: A percentage 0-100 that indicates how much brightness is needed
     - Returns: The adjusted image
     */
    public mutating func blueHazePreset(alteration:UInt8?=100) -> UIImage {
        let reducedAlteration = getReducedAlteration(alteration!)
        let contrastAmount = Int(10 * reducedAlteration)
        let brightnessAmount = Int(-5 * reducedAlteration)
        let redAlteration = Int(-16 * reducedAlteration)
        let greenAlteration = Int(0 * reducedAlteration)
        let blueAlteration = Int(20 * reducedAlteration)
        
        contrast(contrastAmount)
        brightness(brightnessAmount)
        return saturate(redAlteration, greenAlteration: greenAlteration, blueAlteration: blueAlteration)
    }
    
    /**
     Creates a instagram like preset called 'red eye'
     
     - Parameter alteration: A percentage 0-100 that indicates how much brightness is needed
     - Returns: The adjusted image
     */
    public mutating func redEyePreset(alteration:UInt8?=100) -> UIImage {
        let reducedAlteration = getReducedAlteration(alteration!)
        let contrastAmount = Int(10 * reducedAlteration)
        let brightnessAmount = Int(-5 * reducedAlteration)
        let desaturateAmount = UInt8(10 * reducedAlteration)
        let redAlteration = Int(75 * reducedAlteration)
        let greenAlteration = Int(10 * reducedAlteration)
        let blueAlteration = Int(-25 * reducedAlteration)
        
        contrast(contrastAmount)
        brightness(brightnessAmount)
        desaturate(desaturateAmount)
        return saturate(redAlteration, greenAlteration: greenAlteration, blueAlteration: blueAlteration)
    }
    
    /**
     Creates a instagram like preset called 'combat hardened'
     
     - Parameter alteration: A percentage 0-100 that indicates how much brightness is needed
     - Returns: The adjusted image
     */
    public mutating func combatHardenedPreset(alteration:UInt8?=100) -> UIImage {
        let reducedAlteration = getReducedAlteration(alteration!)
        let contrastAmount = Int(40 * reducedAlteration)
        let brightnessAmount = Int(20 * reducedAlteration)
        let redAlteration = Int(10 * reducedAlteration)
        let greenAlteration = Int(44 * reducedAlteration)
        let blueAlteration = Int(25 * reducedAlteration)
        
        contrast(contrastAmount)
        brightness(brightnessAmount)
        return saturate(redAlteration, greenAlteration: greenAlteration, blueAlteration: blueAlteration)
    }
    
    /**
     Resets the image and removes all filters
     - Returns: The adjusted image
     */
    public mutating func reset() -> UIImage {
        beforeImage = self.originalImage
        image = self.originalImage
        rgbaImage = RGBAImage(image: image)!
        
        totalCalculated = false
        redTotal = 0
        greenTotal = 0
        blueTotal = 0
        
        averageCalculated = false
        redAverage = 0
        greenAverage = 0
        blueAverage = 0
        
        return image
    }
    
    /**
     Allows to quickly specify a preset you want to use with default setup
     Recommended are: "bluehaze", "redeye" and "combathardened"
     Available presets: "desaturate", "saturate", "invert",
        "outline", "contrast", "brightness", "bluehaze", "redeye", "combathardened"
     
     - Returns: The adjusted image
     */
    public mutating func preset(preset:String) -> UIImage {
        switch(preset) {
        case "desaturate":
            return desaturate()
        case "saturate":
            return saturate()
        case "invert":
            return invert()
        case "outline":
            return outline()
        case "contrast":
            return contrast()
        case "brightness":
            return brightness()
        case "bluehaze":
            return blueHazePreset()
        case "redeye":
            return redEyePreset()
        case "combathardened":
            return combatHardenedPreset()
        default:
            return saturate(0, greenAlteration: 0, blueAlteration: 0)
        }
    }
}