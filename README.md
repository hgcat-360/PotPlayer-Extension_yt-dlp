# Parse Streaming by yt-dlp - PotPlayer Extension


## Overview
This is a script for **PotPlayer** extension, which enables PotPlsyer to play streaming video/audio on various sites.  
It follows supported sites or services of **yt-dlp**.  

As for YouTube videos, PotPlayer can basically play them without this extension,  
but it may be useful while YouTube restricts connections to external applications.  
YouTube urges users to log in to YouTube account, but PotPlayer does not have means to log in.  
In that respect, yt-dlp extension can treat web cookies and login to the service account for work-around.  



## Requirements

- [PotPlayer **250226 or later versions** on Windows](https://potplayer.tv/)

- [yt-dlp.exe](https://github.com/yt-dlp/yt-dlp/releases)



## Install

1. Place all files of the archive to the following script folder;  
	(PotPlayer's program folder)\Extension\Media\PlayParse\  

2. Place *yt-dlp.exe* to the following module folder;  
	(PotPlayer's program folder)\Module\  

3. Confirm that **yt-dlp** exists in the extension list of PotPlayer settings  
	Preferences(F5) > Extensions >  Media Playlist/Playitem  

4. Try to open urls of various streaming services with PotPlayer  



## Tune-up

### Extension priority
If you have multiple extensions in the extension list, ones displayed higher take priority.  
As for YouTube, if you want to give priority to PotPlayer's YouTube extension rather than this extension,   
place **yt-dlp** below **YouTube** in the list of extension settings.  
PotPlayer's YouTube extension starts YouTube playback faster than yt-dlp extension.  

### Configuration file
You can custumize behavior by editing the configuration file *yt-dlp.ini*.  
Open it by pushing **Config file** button in extension settings.  
Some functions (including Login to your account or auto update of *yt-dlp.exe*) are available with it.  



## History

- 2025-03-04 First published online



