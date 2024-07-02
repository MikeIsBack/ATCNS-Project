# PLA-Bluetooth-Environment
Repository for the Advanced Topics in Computer and Network Security project, UniPD, M.Sc. Computer Science

## Structure

### Second Part of the Course
In this part, students are required to read papers on specific topics and create slides based on them. Here, you will find our study on **Pin and Password Security**, including paper readings and slides.

### Third Part of the Course
In this part, students are required to select a project and create a paper on it. Here, you will find everything useful, from meetings and technical details to reference papers and more.

Our project involves the creation of a wireless Bluetooth channel describing authentication/missed detection and false alarm. This project was guided under the supervision of PhD Alessandro Lotto.

### More on the Project

**Physical Layer Authentication (PLA)** is a promising approach for ensuring secure wireless communications by leveraging the inherent characteristics of the communication channel itself. In this study, we present a case study focused on Bluetooth channel communications over defined distance ranges, where we investigate the potential of PLA techniques to authenticate legitimate transmissions while distinguishing them from spoofing attacks or non-authentic messages.

The proposed approach relies solely on channel state information, such as signal power levels, signal-to-noise ratio (SNR), and distance-dependent attenuation, without relying on traditional cryptographic methods. Through a parametrized simulation framework, we analyze the behavior of wireless signals transmitted over a Bluetooth channel under various configurations, including different distances, SNR values, and desired false alarm and miss detection rates to refine the simulation.

By examining the effects of interference and signal degradation on the received signal, we demonstrate an efficient decoding algorithm that adapts authentication thresholds dynamically based on the observed signal characteristics. This threshold adaptation mechanism aims to improve authentication performance across varying transmission ranges by mitigating the impact of signal attenuation.

The study evaluates the trade-off between false alarm rates, representing the incorrect classification of authentic transmissions as non-legitimate, and miss detection rates, corresponding to the failure to detect non-authentic transmissions. Through an iterative process of transmitting authentic and non-authentic signals, decoding them using the current threshold values, and adjusting the thresholds based on the observed rates, we determine suitable threshold values for reliable authentication.

This approach allows for the analysis of a study based purely on channel state information. It ensures the study of the potential of a decoding scheme aimed at refining and determining ideal parameters for creating a PLA scheme based on these parameters, considering the "randomness" effect given by additive noise from a theoretical point of view. Many future applications can be based on this, considering the channel state flaws and refining its properties.

Finally, we discuss how many messages are interpreted as legitimate when sent as non-authenticated and how many true messages are found to be wrong, respectively measuring the miss detection and false alarm rate, which dynamically refine the presented simulation.

## Components

- Michael Amista'
- Gabriel Rovesti

