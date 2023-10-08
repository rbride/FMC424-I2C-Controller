# FMC424-I2C-Controller
I2C controller to perform required functions to integrate, monitor and utilize FMC424 Dual QSFP+ Vita 57.1 Compliant Mezzanine Board


TIMING:
The FMC Board Includes to following Components:
![image](https://github.com/rbride/FMC424-I2C-Controller/assets/59383300/84eb64ba-6739-4c3d-86d5-37ee6fe97a22)

According to the data sheets of each respected part, they should all be compliant with I2C fast mode. As a result, I will be implementing a 400KHz Clock generator in this circuit. (Refered to as SCL hereafter)  
Furthemore, the Spec for I2C calls for:
  minimum Low Holding time of 1300ns, 
  minimum High Holding time of 600ns,
A 400Khz CLK has a period of 2500ns. Leaving 600 NS of the duty cycle allocable. 
The i2c Signal repeaters inside of the circuit (PCA9517) have the following Propagation Average propagation delays. 
![image](https://github.com/rbride/FMC424-I2C-Controller/assets/59383300/e26a6fd1-f4a8-4a28-be45-bc09a3cf461e)

Averaging this out to create a good enough generator for this system. I Determined it would be best to add 250ns of the 400khz duty cycle to both the low and high portions of clock signal I desired to generate, as well a remaining 50ns to each of the portions to utilize the remaining allocable duty cycle time

This results in the desire to create a clock generator with the following characteristics
400KHz with a 36% duty cycle (900ns seconds high, 1600ns Low, for each 2500ns Period).