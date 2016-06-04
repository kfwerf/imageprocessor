//: Playground - noun: a place where people can play

import UIKit


/**
 Welcome to my ImageProcessor playground.
 The ImageProcessor is attached to the image and you can play around with it.
 To help you get going i added some examples of how you can use the image processor.
 Note: Help is available for all filters, use alt + click to see documentation
 
 Thanks, Kenneth
*/


// Input
let myImage:UIImage! = UIImage(named: "sample")

// Image with ImageProcessor attached
var processedImage = ImageProcessor(givenImage: myImage)

// Need help? Use alt + click and autocomplete to try out the filters and parameters,
// as well as using the presets. It took me a bit to write :)

// E.g. you want to do multiple filters on the image after eachother
 processedImage.desaturate(UInt8(20))
 processedImage.contrast(10)
 processedImage.saturate(10, blueAlteration: 20, greenAlteration: -30)

// E.g. you want to use a predefined preset and reset the image state
 processedImage.reset()
 processedImage.preset("bluehaze")

// E.g. you want to do multiple filters with default parameters
 processedImage.reset()
 processedImage.outline()
 processedImage.invert()
