# Parse Streaming with yt-dlp - PotPlayer Extension

## Overview
This is an extension for **PotPlayer** including an angel script file, which enables PotPlayer to play streaming videos/musics on various websites.  
When opening URL, PotPlayer would call ***yt-dlp.exe*** temporally and get a playable link from it.  
Supported websites or services follow yt-dlp.  

As for YouTube videos, PotPlayer can basically play them without this extension,  
but it may be useful while YouTube restricts connections to external applications.  
YouTube urges users to log in to YouTube account, but PotPlayer does not have means to log in as is.  
yt-dlp extension can treat web cookies and login so PotPlayer could get around the restriction in some cases with it.  

## Requirements
This repository does not include the following softwares.  
Please prepare them separately in advance.  
This script does not work with PotPlayer older than the version below.  

- [PotPlayer **250226 or later versions** on Windows](https://potplayer.tv/)  

- [yt-dlp.exe](https://github.com/yt-dlp/yt-dlp/)  

## Install

1. Place files of the archive to the following script folder;  
	`(PotPlayer's program folder)\Extension\Media\PlayParse\`  
	>
	>***MediaPlayParse - yt-dlp.as*** and ***yt-dlp_default.ini*** are indispensable.  
	>***yt-dlp_default.ini*** must be updated together with ***MediaPlayParse - yt-dlp.as***.  
	>Change the icon of "MediaPlayParse - yt-dlp.as" to suit your preference by renaming icon files (.ico).   
	>***yt-dlp_radio1/2.jpg*** are playlist thumnail files for online radio.  
	>
	>![2025-03-16_10h29_04](https://github.com/user-attachments/assets/e3950518-e204-488f-a60c-36ba02e8c2fb)  

2. Place *yt-dlp.exe* to the following module folder;  
	`(PotPlayer's program folder)\Module\`  
	>
	>If ***yt-dlp.exe*** is placed in another folder, the script won't call it. (for security reason)  
	>
	>![2025-03-16_12h03_34](https://github.com/user-attachments/assets/9d395cb4-797c-4258-87c0-2db420056d1e)  

3. Confirm that **yt-dlp** exists in the extension list of PotPlayer settings  
	`Preferences(F5) > Extensions >  Media Playlist/Playitem`  
	>
	>If you cannot see it, try to push [**Reload files**] button or reopen PotPlayer.  
	>
	>![2025-03-16_02h02_06](https://github.com/user-attachments/assets/e4aa7177-7ba3-4f8a-8373-dbdd0d83f091)  
	>
	>Also confirm that the extension recognizes the version of "***yt-dlp.exe***" by opening **info** panel.  
	>
	>![2025-03-16_02h06_39](https://github.com/user-attachments/assets/fa517e1c-e837-4326-aff1-c4255994c96b)  

4. Try to open URLs of various online video/music sharing services with PotPlayer  
	>
	>![2025-03-16_15h10_46](https://github.com/user-attachments/assets/9bfe5d03-fb40-424c-8e46-c4057f47d62e)  

## Tune-up

### Extension priority
If you have multiple extensions in the extension list, one shown at upper position takes priority.  
As for YouTube, if you want to give priority to built-in YouTube extension of PotPlayer rather than this extension,   
place **yt-dlp** below **YouTube** by using Up/Down buttons in the extension settings.  
PotPlayer's YouTube extension can start YouTube playback more quickly than yt-dlp extension.  
If the preferred extension fails to process the task, it will be handed over to a lower extension.  

### Configuration file
You can customize behavior by editing the configuration file *yt-dlp.ini*.  
Open it by pushing [**Config file**] button in extension settings.  
Some functions (including login to your account or auto update of *yt-dlp.exe*) are available with it.  
You have description of each setting in the configuration file.  

![2025-03-16_02h11_12](https://github.com/user-attachments/assets/265f0fd4-2ae0-4968-9ca7-7d973ce95644)  

Available setting keys are pre-determined and you can always see them in the configuration file.  
To initialize keys or sections, just delete them.  
You can comment out keys with "//". (it is different from the original comment out symbol in ini files, but designed as this here for visibility)  
If some lines are judged to be comments, they are automatically marked with '//' at the beginning of them.  

In fact, it has also "hidden keys" that are usually invisible.  
You can find them in *yt-dlp_default.ini* file in the script folder, where they have the character **#** at the top.  
These keys are not often used or not recommended.  
If you want to use some key among them, just write the key (without **#**) and set its value as normal.  
You can see the usage of each key in the description on [yt-dlp site](https://github.com/yt-dlp/yt-dlp/blob/master/README.md).  

In the configuration file, you can change section order if you like.  
For example, if you often use [MAINTENANCE] section, you can move that section near the beginning of the file by cutting and pasting of the section area.  
But key order within each section is not changable.  

### Update yt-dlp.exe

It is recommended for you to often update *yt-dlp.exe* so it can keep to support more websites.  
If a website has changed specifications, yt-dlp may easily lost the way to handle URLs in it.  
As a result, yt-dlp needs constant modifications and needs to be updated.  

You can use nightly channel to quickly reflect the latest changes.  
See: https://github.com/yt-dlp/yt-dlp/blob/master/README.md#update  

|release channel|url|
|---|---|
|Stable (default) channel| https://github.com/yt-dlp/yt-dlp/releases |
|Nightly channel| https://github.com/yt-dlp/yt-dlp-nightly-builds/releases |

This extension has the function to update *yt-dlp.exe* automatically.  
If you are using nightly channel, auto updator will also follow nightly channel and update *yt-dlp.exe* in finding a new version in nightly channel.  

## Extract playlist

Each website may have its own playlist.  
If yt-dlp support the specified playlist URL, it will import items in the playlist into the playlist panel of PotPlayer when you open the playlist as a new url.  
This behaves the same as the processing of YouTube playlists implemented by PotPlayer   

There is a huge variety of playlists on the web, but yt-dlp can handle only a small part of them.  
In addition, when a playlist has just a few items, you may be able to get all of them, but in the case of a larger number of items, you may not download them at all no matter how long you wait.  

For YouTube playlists, it's recommend to leave it to PotPlayer, but you can also change the script configuration file to process YouTube playlists using yt-dlp.  

A playlist of PotPlayer's format is called **album**.  
Just like with YouTube, you can create an album with a playlist URL as external playlist.  
It will be updated to the latest streaming program whenever you click the album tab in the playlist panel.  

## Cookie Retrieval and Login

When enjoying online videos/musics, some contents or survices may sometimes require you to log in to your account on the website. (for age verification or high-quality supported or special contents, etc)  

And YouTube may sometimes be restricted to prevent you from watching unless you log in.  

In these cases, it is necessary for yt-dlp to have a function about log in.  
There are some ways for yt-dlp to log in to the service account, and using cookies is considered to be the most realistic method (as of 2025).  

If using cookies, you must pass the cookies that your browser created to yt-dlp when logging in to each service.  
There are two ways to do this as following;  

* Specify a browser name and let yt-dlp extract cookies automatically [>>](#automatically-extract-cookies)  

* Prepare a cookie file manually and tell yt-dlp the location of the file [>>](#prepare-a-cookie-file-manually)  

### Automatically extract cookies

It is the simplest method, that is just to specify the browser name.  
But as of March 2025, the available browser of this method on Windows is virtually only Firefox.  
So you are required to use Firefox and log in to target websites with it in advance.  

>Previously, Chromium-based browsers such as Chrome or Edge were able to be used for extracting cookies automatically, just like Firefox, but they have become unusable since around June 2024.  
>This is because the act of automatically extracting cookies from other programs has been prevented due to security reasons.  
>Automatic cookie extraction may eventually become unavailable with Firefox too in the future.  

In the configuration file of the extension, specify the value of "*cookie_browser*" key in [COOKIE] section as follows:  

	cookie_browser=firefox

While you are logging in to the target website in Firefox, you can then watch the login content of the site with PotPlayer/yt-dlp by this method.  
Once you create login cookies, you can close Firefox while using PotPlayer.  
When closing the target website in Firefox, keep the site logged in to (do not log out).  
You must not enable settings that delete cookies when closing Firefox.  

>Note: If you log out of the target website using Firefox, you cannot log in to that site with PotPlayer/yt-dlp because yt-dlp losts login cookies.  
>In that case, you will be able to log in with PotPlayer/yt-dlp again if you log in with Firefox again,  

If you are using [Multi-Account Containers of Firefox](https://support.mozilla.org/kb/containers), you must be logging in to the target website with at least one container.  
If you are playing online videos/musics in a specific container, you can use limited cookies only associated with that container.  
For example, if the name of your target container is "Video & Music", add it to the end of key value like this;  

	cookie_browser=firefox::Video & Music

Most characters are supported here besides English characters.  

Even if you are a Chrome or Edge user, you can use this automatic extraction to prevent the trouble of manually extracting cookies.  
In that case, use Firefox as a secondary browser (sub-browser) and log in to each website with it.  

### Prepare a cookie file manually

About extracting cookies, see also: https://github.com/yt-dlp/yt-dlp/wiki/Extractors  

Here we will explain how to use Chrome and its extension "*Get cookies.txt LOCALLY*" to create a cookie file and pass it to the script.  
**Basically these steps are also available for most browsers besides Chrome.**  

1. In advance, create or register the account of the target website using Chrome  

2. Add the extension "[*Get cookies.txt LOCALLY*](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)" to Chrome  
	>
	>"*Get cookies.txt LOCALLY*" can also be used with other Chromium based browsers such as Edge.  
	>Note: "*Get cookies.txt*" **without LOCALLY** is another extension that has been banned.  

3. Create a cookie file using Chrome and its extension "*Get cookies.txt LOCALLY*"  
	>
	>This cookie file is to be placed in a suitable folder that is not visible from the outside.  
	>For more information about extraction methods, see the next chapter. ([simple method](#simple-method--add-websites-one-by-one) and [stable method](#stable-method--prevent-interference-with-browser))  

4. Open the configuration file of the extension and as the value of "*cookie_file*" key in [COOKIE] section, specify the path to the cookie file you saved  
	>
	>Example 1  
	
		cookie_file=C:\MyData 2025 3\♨secret☹\cookie2503.txt
	
	>Example 2  
	
		cookie_file=%APPDATA%\PotPlayerMini64\Extension\Media\PlayParse\cookies01.txt

#### Simple method ~ add websites one by one

1. Open the target website in Chrome and log in to your account  

2. Call "*Get cookies.txt LOCALLY*" and use [**Export As**] button to save cookies of that website as a file  

3. If treating multiple websites, you need to repeat the above and merge the cookie files into one file  

In this method, the token associated with cookies is shared between your browser and yt-dlp.  

>Generally, if you log out of a target website using your browser, the cookies will be discarded and the token about them will be deactivated.  
>In that case, you will not be able to log in with PotPlayer/yt-dlp and will need to re-extract the cookies again.  
>To create independent cookies that calls a token separate from the browser, use the next stable method.  

When saving a cookie file, you can collect all cookies in the browser by using [**Export All Cookies**] button.  
But it is not recommended considerring security risk, for it may include a large number of websites that are unrelated to yt-dlp (such as ones about exchange of money).  
Although [Export All Cookies] button is used in the next "stable method", in that case websites are collected only within "secret window" opened temporally.  

#### Stable method ~ prevent interference with browser

This is the way to use "secret window" in your browser to create a cookie file that combines all the necessary websites.  
Secret window is also called Private or InPrivate window depending on the browser.  

1. Open the details of "*Get cookies.txt LOCALLY*" from the extension settings of Chrome and allow it to run in secret mode  

2. Opens the Chrome secret window  
	>
	>secret window can be opened using the menu button in the top right of the browser.  
	>To remove unnecessary cookies, leave "Block third party cookies" or "Enhanced tracking prevention" on.  

3. Open the target websites in order and log in to the account on each site, then close them  
	>
	>Do not close the secret window itself, but simply close the tabs for each website.  
	>To prevent the secret window from exiting at this time, open a new tab and then close the website tab.  
	>Do not log out of each website (close the tab while logging in).  

4. Call "*Get cookies.txt LOCALLY*" in the secret window and use [**Export All Cookies**] button to save cookies from all websites in the window as a file  
	>
	>All cookies for each website that was once opened in the secret window will be stored.  

5. Close the secret window  
	>
	>By closing the secret window, the cookies of the window will be discarded in the browser,  
	>and the copied cookie and linking token will be only for yt-dlp.  

In this method, yt-dlp will get the token different from your browser so yt-dlp (or PotPlayer) and your browser are less likely to be affected by each other.  
Even if some website like YouTube is tightening regulations, the scope of the impact may be reduced.  


#### For Firefox

Firefox also has an extension like [cookies.txt](https://addons.mozilla.org/firefox/addon/cookies-txt/) and similarly you can extract a cookie file manually with Firefox.  

If using "private window" to create a cookie file as "Stable method" above, PotPlayer/yt-dlp won't be affected by the login status of Firefox.  

If you are using [Multi-Account Containers of Firefox](https://support.mozilla.org/kb/containers), cookies are distinguished by container.  
When saving a cookie file in the case of "simple method" above, you can choose the container that you usually use for playing videos/musics.  

#### Supplement 

Unless you log out, the cookie file should be able to last a certain amount of time.  
However, the expiration date for login cookies is usually set to six months or one year, for example, and is not permanent.  
Cookies and tokens associated with cookies may be invalidated due to a variety of other factors.  
If you notice that it is no longer available, simply recreate the cookie file.  

## History

- 2025-03-16 Published.  


