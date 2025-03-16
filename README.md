# Parse Streaming with yt-dlp - PotPlayer Extension


## Overview
This is an extension for **PotPlayer** including an angel script file, which enables PotPlayer to play streaming videos/audios on various sites.  
When opening url, PotPlayer would call ***yt-dlp.exe*** temporally and get a playable link from it.  
Supported sites or services follow yt-dlp.  

As for YouTube videos, PotPlayer can basically play them without this extension,  
but it may be useful while YouTube restricts connections to external applications.  
YouTube urges users to log in to YouTube account, but PotPlayer does not have means to log in as is.  
yt-dlp extension can treat web cookies and login so PotPlayer could get around the restriction in some cases with it.  



## Requirements
This repository does not include the following softwares.  
Please prepare them separately.  
This script does not work with PotPlayer older than the version below.  

- [PotPlayer **250226 or later versions** on Windows](https://potplayer.tv/)

- [yt-dlp.exe](https://github.com/yt-dlp/yt-dlp/releases)



## Install

1. Place all files of the archive to the following script folder;  
	`(PotPlayer's program folder)\Extension\Media\PlayParse\`
	>***MediaPlayParse - yt-dlp.as*** and ***yt-dlp_default.ini*** are indispensable.  
	>Change the icon of "MediaPlayParse - yt-dlp.as" if you like by renaming icon files (.ico).   
	>  
	>![2025-03-16_10h29_04](https://github.com/user-attachments/assets/e3950518-e204-488f-a60c-36ba02e8c2fb)  

2. Place *yt-dlp.exe* to the following module folder;  
	`(PotPlayer's program folder)\Module\`  
	>If ***yt-dlp.exe*** is placed in another folder, the script won't call it. (for security reason)  
	>  
	>![2025-03-16_12h03_34](https://github.com/user-attachments/assets/9d395cb4-797c-4258-87c0-2db420056d1e)

3. Confirm that **yt-dlp** exists in the extension list of PotPlayer settings  
	`Preferences(F5) > Extensions >  Media Playlist/Playitem`
	>  
 	>If you cannot see it, try to push **reload** button or reopen PotPlayer.
	>![2025-03-16_02h02_06](https://github.com/user-attachments/assets/e4aa7177-7ba3-4f8a-8373-dbdd0d83f091)  
	>  
 	>Also confirm that the extension recognizes the version of "***yt-dlp.exe***" by opening **info** panel.  
 	>![2025-03-16_02h06_39](https://github.com/user-attachments/assets/fa517e1c-e837-4326-aff1-c4255994c96b)  

4. Try to open urls of various streaming services with PotPlayer  



## Tune-up

### Extension priority
If you have multiple extensions in the extension list, one shown at upper position takes priority.  
As for YouTube, if you want to give priority to PotPlayer's YouTube extension rather than this extension,   
place **yt-dlp** below **YouTube** by using Up/Down buttons in the extension settings.  
PotPlayer's YouTube extension can start YouTube playback more quickly than yt-dlp extension.  
If the preferred extension fails to process the task, it will be handed over to a lower extension.  

### Configuration file
You can customize behavior by editing the configuration file *yt-dlp.ini*.  
Open it by pushing **Config file** button in extension settings.  
Some functions (including login to your account or auto update of *yt-dlp.exe*) are available with it.  
You have description of each settings in detail on the config file.  
![2025-03-16_02h11_12](https://github.com/user-attachments/assets/265f0fd4-2ae0-4968-9ca7-7d973ce95644)  



## History

- 2025-03-15 Published.


