# smart_feeder
Smart Feeder device developed at Auburn University

Current deer feeder products on the market operate with a limited button control pad, an LCD screen for feedback, a timer, and a DC motor.  Users must interact with the device directly and are limited to setting feed events at discrete times.  These interactions are time consuming as each device must be taken apart and interacted with physically one by one, prone to human error as the device has limited inputs, and require significant adjustments as the daylight hours shift throughout the year and deer feeding behaver is relative to daylight.  Keeping multiple feeders in sync is also difficult due to the manual setting of the clocks and feed events on multiple devices.  

The premise for the Smart Feeder comes from the Auburn School of Forestry and Wildlife Sciences (SFWS): enhance the existing market offerings by making a feeder that is managed by a mobile application, using the capabilities of that device to enhance the user experience.

The Smart Feeder developed consisted of two separate R&D efforts as both a hardware system for the device and a software system for a user interface were needed.  The hardware system is an embedded system capable of communicating wirelessly over Bluetooth Low Energy (BLE), performing calculations to determine sunrise and sunset times, and circuitry to drive a DC motor.  The software system is an iOS application allowing users to configure schedules based on discrete times or sunrise/sunset events and send all needed information, including time and location data, over BLE to the hardware system. Together, these systems address the usability issues with the current products.
