﻿﻿
# Parse Streaming with yt-dlp - PotPlayer Extension

<br>

## Overview

### PotPlayer and yt-dlp

**PotPlayer** is one of the most powerful media players on Windows.  
However, for online media services except for YouTube, PotPlayer can only play direct media links.  
This extension enables PotPlayer to play various video and audio streams from common webpage URLs.  
When PotPlayer opens a webpage URL, this extension temporarily runs ***yt-dlp.exe*** to retrieve a playable link.  
The extension also retrieves content metadata such as title, thumbnail, uploader, and duration.  

### Supported Websites

Websites and services supported by this extension are largely the same as those supported by *yt-dlp.exe*, with some exceptions.  
As a general rule, yt-dlp does not support sites that are obviously pirated.  
It is also not expected to handle paid content (usually protected with DRM).  
However, if it is DRM-free, yt-dlp can sometimes access it by logging in with a paid account.  

### YouTube Restrictions

For YouTube, PotPlayer can generally play YouTube videos without this extension,  
but it can be useful when YouTube restricts access from external applications.  
Although YouTube sometimes requires users to log in, PotPlayer has no built-in login feature for standard playback.  
This extension uses yt-dlp to handle web cookies and login authentication, allowing PotPlayer to bypass certain restrictions.  

<br>

## Requirements

PotPlayer is a Windows-only media player, so this extension is intended for use on Windows.  

The following applications are **not** included in this repository. Please obtain them separately.  

* [PotPlayer](https://potplayer.tv/)  
	
	This yt-dlp extension currently supports PotPlayer **260114 or later**.  
	Older versions of this extension (before 260213) support PotPlayer **250226 or later**.
	
	Development builds of PotPlayer are available from the [developer community](https://cafe.daum.net/pot-tool) (Korean).  
	Using Google Translate on this community site may cause page reload errors.  
<br>

* [yt-dlp.exe](https://github.com/yt-dlp/yt-dlp/)  
	
	**Using the latest version is always recommended** for proper website support.  
	
	*yt-dlp.exe* also provides nightly builds.  
	See [Updating yt-dlp](#updating-yt-dlpexe).  
<br>

In addition, you may need the following commands:  
<br>

* [deno.exe](https://github.com/denoland/deno)  
	
	Required for full YouTube support.  
	At present, **yt-dlp** cannot fully support YouTube without an external JavaScript runtime such as **deno**.  
	See: https://github.com/yt-dlp/yt-dlp/issues/15012  
	
	When using **deno**, download ***deno-x86_64-pc-windows-msvc.zip*** from the release page.  
	Then place the extracted *deno.exe* in the same folder as *yt-dlp.exe* or in a folder included in the system PATH.  
<br>

* [ffmpeg.exe](https://ffmpeg.org/download.html#build-windows)  
	
	***ffmpeg.exe*** is usually not required, since this extension uses *yt-dlp.exe* only to parse URLs and does not download media content.  
	However, *yt-dlp.exe* may occasionally hang when *ffmpeg.exe* is not available. (See [Process Not Responding](#process-not-responding))  
	
	Download a build of **FFmpeg version 8 or later** and place the extracted *ffmpeg.exe* in the same folder as *yt-dlp.exe* or in a folder included in the system PATH.  
<br>

* [curl.exe](https://curl.se/windows/)  
	
	Used to retrieve server data.  
	Some features of this extension do not work without **curl**.  
	
	Windows 10 and later include **curl.exe** in the system folder by default.  
	On windows versions earlier than 10, manual setup is required.  
	Place *curl.exe* in the *system32* folder or in a folder included in the system PATH.  
<br>

## Installation

Follow the steps below to install this extension.  
Make sure that PotPlayer is installed in advance.  

1. Download *Source code (zip)* from the Assets section of the release page.  
     
    ![Set yt-dlp extension 0](https://github.com/user-attachments/assets/c22660f0-64f0-4152-b1a0-5c2f1394d758)  
<br>

2. Extract the downloaded files to the script folder.  
    
    `(PotPlayer installation folder)\Extension\Media\PlayParse\`  
    
    <img width="681" height="376" alt="2026-07-03_22h08_31" src="https://github.com/user-attachments/assets/30025e16-d8c1-49aa-91fc-7f80af64eac0" />

    
    ***MediaPlayParse - yt-dlp.as*** and ***yt-dlp_default.ini*** are required.  
    You must always update *yt-dlp_default.ini* at the same time as *MediaPlayParse - yt-dlp.as*.  
    
    You can customize the icon of *MediaPlayParse - yt-dlp.as* by renaming *.ico files.  
    ***yt-dlp_radio1.jpg*** and ***yt-dlp_radio2.jpg*** are thumbnails for online radio, displayed in PotPlayer's album view.  
    ***yt-dlp_playlist.jpg*** might be used as a thumbnail for website playlists.  
    
    Other files in this repository are not required in this folder.  
<br>

3. Place *yt-dlp.exe* in PotPlayer's module folder:  
    
    `(PotPlayer installation folder)\Module\`  
    
    <img width="605" height="435" alt="2026-07-03_21h09_30" src="https://github.com/user-attachments/assets/f1c5314a-b1ed-4573-8173-42ce1389c806" />
    
    You can change this folder using the ***ytdlp_location*** setting in the [MAINTENANCE] section of the configuration file.  
    If *yt-dlp.exe* is not found, this extension will return an error.  
    
    Also place ***ffmpeg.exe*** and ***deno.exe*** in the same folder as *yt-dlp.exe*, or add thier location to the system PATH.  
    (*deno.exe* is required for proper YouTube support)  
<br>

4. Confirm that **yt-dlp** appears in PotPlayer's extension list:  
    
    `Preferences (F5) > Extensions > Media Playlist/Playitem`  
    
    ![2025-03-16\_02h02\_06](https://github.com/user-attachments/assets/e4aa7177-7ba3-4f8a-8373-dbdd0d83f091)
    
    If not visible, click [**Reload files**] or restart PotPlayer.  
    Also verify the extension detects the version of ***yt-dlp.exe*** in the **info** panel.  
    
    ![2025-03-16\_02h06\_39](https://github.com/user-attachments/assets/fa517e1c-e837-4326-aff1-c4255994c96b)
<br>

5. Try opening URLs from various online video/audio services using PotPlayer.  
    
    ![Open URLs](https://github.com/user-attachments/assets/edee7d70-eb46-462e-a26c-aef92f4842ea)  
<br>

## Tune-up

### Extension Priority

When multiple extensions are enabled, the higher one in the list takes priority.  
For YouTube, if you prefer PotPlayer’s built-in YouTube extension over this one,
move **yt-dlp** below **YouTube** using the Up/Down buttons in the **Media Playlist/Playitem** setting.  
PotPlayer’s built-in YouTube extension generally starts playback faster.  
If the preferred extension fails to process a URL, the task is passed to the next extension.  

![2025-08-14\_22h01\_22](https://github.com/user-attachments/assets/27bc5fc6-1fc5-42e8-aa1f-9d4059649216)

<br>

### Configuration File

You can customize the behavior by editing the *yt-dlp.ini* configuration file.  
Open it in a popup panel via the [**Config file**] button that appears when you select **yt-dlp** in the extension settings list.  
Some features, including account login and automatic *yt-dlp.exe* updates, are controlled here.  
Each setting has a description inside the file.  

![2025-08-14\_22h23\_34](https://github.com/user-attachments/assets/e91f9bdf-af11-4397-930a-b4ce2726e21f)

Available keys are predefined and always visible in the *yt-dlp.ini* panel.  
To reset keys or sections, delete them from the file — they will be restored with default values automatically.  

#### Comment out
You can comment out lines by adding "**//**" at the beginning of the line.   
(This differs from standard INI syntax, but is designed for better visibility.)  
A line can be toggled between disabled and enabled by adding or removing "**//**".  
If the extension considers a line to be a comment, it automatically prefixes it with "**//**".  

#### Hidden keys
There are also “hidden keys” that are not normally listed in *yt-dlp.ini* but appear in *yt-dlp_default.ini* with a “**#**” prefix.  
To use these keys, add them to *yt-dlp.ini* without the “**#**” and set their values there.  
(Do not edit *yt-dlp_default.ini* directly.)  

#### Reorder sections
You can reorder sections in *yt-dlp.ini* as you like.  
For example, move the frequently used [MAINTENANCE] section near the top by cutting and pasting.  
However, the order of keys within each section cannot be changed.  

<br>

### Updating *yt-dlp.exe*

Regularly updating *yt-dlp.exe* is recommended to maintain compatibility with more websites.  
If a website changes its specifications, yt-dlp may stop working with that site until it is updated.  

You can use a nightly build for the latest fixes:  
See the [yt-dlp README](https://github.com/yt-dlp/yt-dlp/blob/master/README.md#update)  

| Release Channel  | URL                                                                                                                  |
| ---------------- | -------------------------------------------------------------------------------------------------------------------- |
| Stable (default) | [https://github.com/yt-dlp/yt-dlp/releases](https://github.com/yt-dlp/yt-dlp/releases)                               |
| Nightly          | [https://github.com/yt-dlp/yt-dlp-nightly-builds/releases](https://github.com/yt-dlp/yt-dlp-nightly-builds/releases) |

This extension supports automatic updates of *yt-dlp.exe*.  
When using a nightly build, the updater will track and install the latest nightly build automatically.  

If the auto-update fails due to write permissions, you can change the location folder to place *yt-dlp.exe* in.  
Please use the ***ytdlp_location*** setting in the [MAINTENANCE] section of the configuration file.  

---------
<br>

## Notes

### Option Selection Criteria

When PotPlayer opens a webpage URL from a site other than YouTube, that URL must be supported by yt-dlp.  

|                                                      | YouTube                                       | non-YouTube sites         |
| ----------------------------------------- | ------------------------------------------ | --------------------------- |
| Default PotPlayer (built-in)                | normal viewing                              | not available                |
| yt-dlp extension                              | when default is restricted                | regular content             |
| yt-dlp extension + login                   | login-only content / when restricted | login-only content           |
| yt-dlp extension + login + PO Token | when strongly restricted                 | (ignore PO Token)           |
| Internet Browser (Chrome etc.)      | most reliable                               | most reliable                  |

If playback fails, try the available options in order.  

- PotPlayer does not require cookies or login when using its default method for accessing YouTube.  
However, PotPlayer includes built-in workarounds that can bypass some YouTube restrictions, although they may not work in all cases.  

- For login, see [Get Cookies and Login](https://github.com/hgcat-360/PotPlayer-Extension_yt-dlp/wiki/Get-Cookies-and-Login).  
At present, YouTube login requires a JavaScript runtime such as ***deno.exe***.  

- For PO Token, see [PO Token Guide](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide).  
At present, obtaining PO Tokens for YouTube playback generally requires a `PO Token Provider` plugin, since a different token may be required for each video.  

#### Login or Logout

Login can be an effective workaround for restrictions on some services such as YouTube.  
For most users, enabling login is recommended.  

Sometimes, playback may work without login but fail when login is enabled.  
This depends on which connections a website is restricting at the time.  

If you cannot play videos on a certain site while logged in, try logging out, clearing that site's cookies in your browser, and then logging in again.  
If you use a cookie file for this extension, recreate it from the same browser after logging in again.  

If your account or cookies appear to be restricted by the site, avoid using cookies for that site for a while.  

<br>

### Process Not Responding

After PotPlayer invokes *yt-dlp.exe* through the yt-dlp extension, it takes some time to obtain the available links.  
When extracting a large playlist, the import may take several minutes to complete.  
If necessary, adjust the timeout settings in the [TARGET] section of the configuration file, especially ***playlist_metadata_timeout***.  

Aside from this, *yt-dlp.exe* may occasionally hang while processing a URL.  
In such cases, PotPlayer will remain stuck on the “*Opening...*” message.  
If *yt-dlp.exe* hangs for opening a YouTube video that was uploaded within the past few days, make sure that *ffmpeg.exe* is available to *yt-dlp.exe*.  

#### Stop yt-dlp Process

If the playback does not start even after waiting, press PotPlayer's Stop button to halt the loading process.  
Next, check whether any *yt-dlp.exe* processes are still running in the background.  
If any are found, terminate them forcibly to prevent unnecessary resource usage.  
However, if *yt-dlp.exe* is not actually hanging and is only taking a long time to process, its process will eventually terminate automatically.  

Note that PotPlayer or yt-dlp cannot forcibly terminate these processes on their own.  
You will need to use your system’s **Task Manager** or, preferably, a more user-friendly external tool such as [Process Explorer](https://learn.microsoft.com/sysinternals/downloads/process-explorer) or [System Explorer](https://systemexplorer.net/).  

<img width="959" height="475" alt="2025-08-15\_21h14\_42" src="https://github.com/user-attachments/assets/6afc599a-1f96-4091-993f-40dad6b4071f" />

It’s a basic shortcoming that you have to monitor processes with an external tool.  
This comes from server restrictions, faulty processing of *yt-dlp.exe* and limitations in the design of the PotPlayer extension.  

<br>

---------

## FAQ

### How can I check whether the extension is working?
To monitor the extension behavior in real time:  

- Monitor the *yt-dlp.exe* process as a child process of *PotPlayerMini(64).exe* using an external process monitoring tool.  
See [Process not responding](#process-not-responding)  

- Open the console window for PotPlayer extensions  
See [Enabling console log output](https://github.com/hgcat-360/PotPlayer-Extension_yt-dlp/wiki/Console-Log-Output-Notes#enabling-console-log-output)  

You can also compare the behavior by toggling the ***stop*** setting in the configuration file.  

### Why does the extension stop when the console is displayed?
When text is selected in the console window, the extension pauses.  
See: https://github.com/hgcat-360/PotPlayer-Extension_yt-dlp/wiki/Console-Log-Output-Notes#text-selection-pauses-the-extension

### How can I configure login for websites?
The easiest way is to log in to the service website in advance using **Firefox**.  
Alternatively, you can create a cookie file manually.  
See: https://github.com/hgcat-360/PotPlayer-Extension_yt-dlp/wiki/Get-Cookies-and-Login

### Are "PO Tokens" necessary for YouTube?
*yt-dlp* recommends using [**PO Tokens**](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide) for YouTube.  
However, in many cases, PO Tokens are not required for YouTube playback.  
Try enabling login first and use *yt-dlp.exe* together with ***ffmpeg.exe*** and a JavaScript runtime such as ***deno.exe*** before considering PO Tokens.  

### Too many items in PotPlayer's quality menu - how can I reduce them?
Configure the ***reduce_formats*** setting in the [FORMAT] section of the configuration file according to your network bandwidth.  

### How can I prevent auto-update failures of *yt-dlp.exe*?
If the issue is caused by write permission restrictions, change the folder location of *yt-dlp.exe* using the ***ytdlp_location*** setting in the [MAINTENANCE] section of the configuration file.  
You can also run PotPlayer with administrator privileges, but this may restrict access to media files due to permission differences.  

### Why is the same YouTube page sometimes treated as a playlist and sometimes as a single video?
Check whether the URL includes a playlist ID.  
See: https://github.com/hgcat-360/PotPlayer-Extension_yt-dlp/wiki/Extracting-Playlists#playlist-or-single-video

### Stream loading is unstable or fails in PotPlayer. What can I do?
Try changing the source filter used by PotPlayer.  
See: https://github.com/hgcat-360/PotPlayer-Extension_yt-dlp/wiki/Streaming-Source-Filter

### How can I automatically skip promotion or intro segments on YouTube using SponsorBlock?
For **SponsorBlock**, configure the chapter categories using the ***sponsor_block*** setting in the [YOUTUBE] section of the configuration file.  
Then enable PotPlayer's auto-skip feature for the corresponding chapter titles.  
See: https://github.com/hgcat-360/PotPlayer-Extension_yt-dlp/wiki/SponsorBlock-on-YouTube

