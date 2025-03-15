# Parse Streaming with yt-dlp - PotPlayer Extension


## Overview
This is a script for **PotPlayer** extension, which enables PotPlayer to play streaming videos/audios on various sites.  
When opening url, PotPlayer would call ***yt-dlp.exe*** temporally and get a playable link from it.  
Supported sites or services follow yt-dlp.  

As for YouTube videos, PotPlayer can basically play them without this extension,  
but it may be useful while YouTube restricts connections to external applications.  
YouTube urges users to log in to YouTube account, but PotPlayer does not have means to log in as is.  
yt-dlp extension can treat web cookies and login so PotPlayer could get around the restriction in some cases with it.  



## Requirements
This repository does not include the following softwares.  
Please take them separately.

- [PotPlayer **250226 or later versions** on Windows](https://potplayer.tv/)

- [yt-dlp.exe](https://github.com/yt-dlp/yt-dlp/releases)



## Install

1. Place all files of the archive to the following script folder;  
	(PotPlayer's program folder)\Extension\Media\PlayParse\
	***MediaPlayParse - yt-dlp.as*** and ***yt-dlp_default.ini*** are indispensable.  

3. Place *yt-dlp.exe* to the following module folder;  
	(PotPlayer's program folder)\Module\  
	If *yt-dlp.exe* is placed in another folder, the script won't call it. (for security reason)   

4. Confirm that **yt-dlp** exists in the extension list of PotPlayer settings  
	Preferences(F5) > Extensions >  Media Playlist/Playitem  
![2025-03-04_04h20_49](https://github.com/user-attachments/assets/e4bfe285-a625-48bb-a81a-a7b00bc1c0b5)

5. Try to open urls of various streaming services with PotPlayer  



## Tune-up

### Extension priority
If you have multiple extensions in the extension list, one shown at upper position takes priority.  
As for YouTube, if you want to give priority to PotPlayer's YouTube extension rather than this extension,   
place **yt-dlp** below **YouTube** by using Up/Down buttons in the extension settings.  
PotPlayer's YouTube extension can start YouTube playback more quickly than yt-dlp extension.  

### Configuration file
You can customize behavior by editing the configuration file *yt-dlp.ini*.  
Open it by pushing **Config file** button in extension settings.  
Some functions (including login to your account or auto update of *yt-dlp.exe*) are available with it.  
You have description of each settings in detail on the config file.


## History

- 2025-03-04 First upload to github.


