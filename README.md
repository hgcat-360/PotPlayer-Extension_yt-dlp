# Parse Streaming with yt-dlp - PotPlayer Extension

## Overview

***The yt-dlp extension*** for **PotPlayer** includes an AngelScript file that enables PotPlayer to play streaming videos or audio tracks from a variety of websites.  
With this yt-dlp extension, when opening a URL, PotPlayer temporarily runs yt-dlp.exe to obtain a playable link.  

The supported websites and services are largely the same as those supported by yt-dlp.exe, with some exceptions.  
As a general rule, yt-dlp **does not support** commercial services for paid members, DRM-protected content, or obvious pirate sites.  

For YouTube, PotPlayer can generally play YouTube videos without this extension, 
but it can be useful when YouTube restricts access from external applications.  
Although YouTube sometimes requires users to log in, PotPlayer has no built-in login feature for standard playback.  
This extension uses yt-dlp to handle web cookies and login authentication, allowing PotPlayer to bypass certain restrictions.  

## Requirements

PotPlayer is a Windows-only media player, so this extension is intended for use on Windows.  

This repository does not include the following applications. You must obtain them separately.  

* [PotPlayer (**250226 or later**)](https://potplayer.tv/)
* [yt-dlp.exe](https://github.com/yt-dlp/yt-dlp/)

## Installation

Follow these steps to install this extension.  
Make sure that PotPlayer is installed in advance.  

1. Extract the archive files to the script folder:  
   `(PotPlayer program folder)\Extension\Media\PlayParse\`  
   > ***MediaPlayParse - yt-dlp.as*** and ***yt-dlp\_default.ini*** are required.  
   > You must always update *yt-dlp_default.ini* at the same time as *MediaPlayParse - yt-dlp.as*.  
   > You can customize the icon of *MediaPlayParse - yt-dlp.as* with the *.ico files renamed.  
   > ***yt-dlp\_radio1.jpg*** and ***yt-dlp\_radio2.jpg*** are thumbnails for online radio, displayed in the PotPlayer's playlist panel.  
   >Other files in the repository are not required in this folder.
   >  
   > ![2025-03-16\_10h29\_04](https://github.com/user-attachments/assets/e3950518-e204-488f-a60c-36ba02e8c2fb)

2. Place *yt-dlp.exe* in the module folder:  
   `(PotPlayer program folder)\Module\`  
   > For security reasons, the script calls *yt-dlp.exe* only from this folder.  
   > If *yt-dlp.exe* is not found here, this script will return an error.  
   >  
   > ![2025-03-16\_12h03\_34](https://github.com/user-attachments/assets/9d395cb4-797c-4258-87c0-2db420056d1e)  

3. Confirm that **yt-dlp** appears in PotPlayer's extension list:  
   `Preferences (F5) > Extensions > Media Playlist/Playitem`  
   > If not visible, click \[**Reload files**] or restart PotPlayer.  
   >  
   > ![2025-03-16\_02h02\_06](https://github.com/user-attachments/assets/e4aa7177-7ba3-4f8a-8373-dbdd0d83f091)
   >  
   > Also verify the extension detects the version of ***yt-dlp.exe*** in the **info** panel.  
   >  
   > ![2025-03-16\_02h06\_39](https://github.com/user-attachments/assets/fa517e1c-e837-4326-aff1-c4255994c96b)

4. Try opening URLs from various online video/audio services in PotPlayer.  
	>  
	> ![2025-08-14_20h](https://github.com/user-attachments/assets/6032150e-fe3c-4061-8b33-2055f7c5eb82)


## Tune-up

### Extension Priority

When multiple extensions are enabled, the higher one in the list takes priority.  
For YouTube, if you prefer PotPlayer’s built-in YouTube extension over this one,
move **yt-dlp** below **YouTube** using the Up/Down buttons in the **Media Playlist/Playitem** setting.  
PotPlayer’s built-in YouTube extension generally starts playback faster.  
If the preferred extension fails to process a URL, the task is passed to the next extension.  

![2025-08-14_22h01_22](https://github.com/user-attachments/assets/27bc5fc6-1fc5-42e8-aa1f-9d4059649216)

### Configuration File

You can customize the behavior by editing the *yt-dlp.ini* configuration file.  
Open it in a popup panel via the \[**Config file**] button that appears when you select **yt-dlp** in the extension settings list.  
Some features, including account login and automatic *yt-dlp.exe* updates, are controlled here.  
Each setting has a description inside the file.  

![2025-08-14_22h23_34](https://github.com/user-attachments/assets/e91f9bdf-af11-4397-930a-b4ce2726e21f)

Available keys are predefined and always visible in the *yt-dlp.ini* panel.  
To reset keys or sections, delete them from the file — they will be restored with default values automatically.  
You can comment out lines by adding "//" at the start (different from standard INI syntax, designed for better visibility).  
Lines detected as comments are automatically prefixed with "//".  

There are also “hidden keys” that are not normally listed in *yt-dlp.ini* but appear in *yt-dlp_default.ini* with a “#” prefix.  
To use these keys, add them to *yt-dlp.ini* without the “#” and set their values there (You should not edit *yt-dlp_default.ini* directly).  

You can reorder sections in *yt-dlp.ini* as you like.  
For example, move the frequently used \[MAINTENANCE] section near the top by cutting and pasting.  
However, the order of keys within each section cannot be changed.  

### Updating yt-dlp.exe

Regularly updating yt-dlp.exe is recommended to maintain compatibility with more websites.  
If a website changes its specifications, yt-dlp may stop working with that site until it is updated.  

You can use the nightly channel for the latest fixes:  
See: [https://github.com/yt-dlp/yt-dlp/blob/master/README.md#update](https://github.com/yt-dlp/yt-dlp/blob/master/README.md#update)  

| Release Channel  | URL                                                                                                                  |
| ---------------- | -------------------------------------------------------------------------------------------------------------------- |
| Stable (default) | [https://github.com/yt-dlp/yt-dlp/releases](https://github.com/yt-dlp/yt-dlp/releases)                               |
| Nightly          | [https://github.com/yt-dlp/yt-dlp-nightly-builds/releases](https://github.com/yt-dlp/yt-dlp-nightly-builds/releases) |

This extension supports automatic updates of *yt-dlp.exe*.  
When using the nightly channel, the updater will track and install nightly builds automatically.  

## Extracting Playlists

### Support for Website Playlists

Each website may provide its own playlist features.  
PotPlayer can extract YouTube playlists by default, and this extension adds support for playlists from many other sites — including YouTube.  
When you open a playlist URL, the yt-dlp extension will import its items into PotPlayer’s playlist if yt-dlp supports that playlist.  

While website playlists vary widely, yt-dlp supports only certain types.  
Small playlists may load completely, but large ones may not load fully even after a long wait.  

### Playlist or Single Video

For YouTube, some URLs contain both a single video and a playlist (e.g., https://www.youtube.com/watch?v=XXXXX&list=YYYYY) and may not look like playlists at first glance.  
PotPlayer treats these as playlists by default, but this extension does not.  
Therefore, enabling the YouTube playlist processing in this extension helps prevent unintended imports of a large number of videos all at once.  
If you want to treat a certain YouTube URL as a playlist, make sure that the URL contains only a playlist ID without any video ID (e.g., https://www.youtube.com/playlist?list=YYYYY).  

However, for websites other than YouTube, if supported, this extension treats URLs that include both a single video (or music track) and a playlist as a playlist.  

This specification is subject to change in the future.  

### External Playlist Albums

In PotPlayer, a playlist in its own format is called an **album**.  
As with YouTube, this extension also allows you to create an album as an "***external playlist***" from a playlist URL on non-YouTube websites.  
An "*external playlist*" is automatically updated with the latest streaming content whenever you click its album tab to bring it into focus in the playlist panel.  

![2025-08-15_03h58_09](https://github.com/user-attachments/assets/27ebd5fe-de63-449a-9ca1-a5eb2aaefa5e)

## Notes

### Process Not Responding

After PotPlayer invokes *yt-dlp.exe* through the yt-dlp extension. it takes some time to obtain the available links.  
When extracting a large playlist, the import may take over five minutes to complete.  
Aside from this, *yt-dlp.exe* may occasionally hang due to failed connections to the target server or errors in interpreting the URL content.

In these situations, PotPlayer will remain stuck in the “*preparing to play*” state.  
If the playback does not start even after waiting, press PotPlayer's Stop button to halt the loading process.  
Next, check whether any *yt-dlp.exe* processes are still running in the background.  
If any are found, terminate them forcibly to prevent unnecessary resource usage.  
However, if yt-dlp.exe is not actually hanging and is only taking a long time to process, its process will eventually terminate automatically.  

Note that PotPlayer or yt-dlp cannot forcibly terminate these processes on their own.  
You will need to use your system’s **Task Manager** or, preferably, a more user-friendly external tool such as [Process Explorer](https://learn.microsoft.com/sysinternals/downloads/process-explorer) or [System Explorer](https://systemexplorer.net/).  

<img width="959" height="475" alt="2025-08-15_21h14_42" src="https://github.com/user-attachments/assets/6afc599a-1f96-4091-993f-40dad6b4071f" />

It’s a basic shortcoming that you have to monitor processes with an external tool.  
This comes from server restrictions, faulty processing of *yt-dlp.exe* and limitations in the design of the PotPlayer extension.  

### Options Selection Criteria

|                                                 | YouTube                                       | Other than YouTube    |
| --------------------------------------- | ------------------------------------------ | -------------------------- |
| Default PotPlayer (built-in)           | normal viewing                              | not available                |
| yt-dlp extention                          | when default is restricted                | regular content            |
| yt-dlp extention +login                | login-only content / when restricted | login-lnly content          |
| yt-dlp extention +login +poToken | when strongly restricted                 | (ignore poToken)           |
| Internet Brower (Chrome etc.)      | most reliable for viewing                | most reliable for viewing |

Although it is not shown in this table, PotPlayer can also play **KakaoTV** by default.  

For login, see [Get Cookies and Login](#get-cookies-and-login).  
For poToken, see [PO Token Guide](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide) and specify it in the extension's configuration file.  

In its default method of accessing YouTube, PotPlayer does not require cookies or login.  
However, it includes built-in workarounds that can bypass some YouTube restrictions more effectively than using the yt-dlp extension without cookies.  

It may seem that the lower options in this table are always superior for viewing capability, but sometimes you may not be able to play YouTube with login even though playback works without login.  
This depends on which connections YouTube is restricting at that time.  

If you cannot watch, try the available options in order.  

## Get Cookies and Login

When watching online videos or listening to music, some services may require you to log in (e.g., for age verification, high-quality playback, or special content).  

On YouTube, for example, certain videos — or even all videos under some conditions — cannot be played unless you are logged in.  

In such cases, as of 2025, using cookies is generally the most practical method for authentication.  
you must pass the cookies from your browser to yt-dlp to log in to each service.  

There are two ways to do this:  

* [Automatically extract cookies from a browser](#automatically-extract-cookies)
* [Manually prepare a cookie file](#prepare-a-cookie-file-manually)

### Automatically extract cookies

This is the simplest method: just specify the browser name.  
However, as of March 2025, this works reliably on Windows only with Firefox.  
You will need to use Firefox and log in to the target websites in advance.  

> Chromium-based browsers (e.g., Chrome, Edge) previously supported automatic cookie extraction, but this stopped working around June 2024 due to security restrictions.
> In the future, Firefox might also block automatic extraction.

In the extension’s configuration file, set the "*cookie\_browser*" key in the \[COOKIE] section like this:  

```
cookie_browser=firefox
```

Once logged in with Firefox, you can watch login-required content in PotPlayer/yt-dlp.  
After creating login cookies, you can close Firefox.  
Keep the site logged in and disable any settings that delete cookies when closing Firefox.  

> **Note:** If you log out in Firefox, yt-dlp will lose access. Log in again in Firefox to restore it.

When using [Firefox Multi-Account Containers](https://support.mozilla.org/kb/containers), you can specify the container name for media playback, and yt-dlp will handle only the cookies associated with that container.  

```
cookie_browser=firefox::Video & Music
```

Even if you primarily use Chrome or Edge, you can keep Firefox as a secondary browser just for automatic cookie extraction.  

### Prepare a cookie file manually

See also: [yt-dlp Wiki – Extractors](https://github.com/yt-dlp/yt-dlp/wiki/Extractors)

Here, we use Chrome and its extension "*Get cookies.txt LOCALLY*" as an example.  
This procedure also works for most other browsers.  

**Note: Do not confuse "*Get cookies.txt LOCALLY*" with "*Get cookies.txt*" (without LOCALLY).**
The one without "LOCALLY" is prohibited as malware.

1. Log in to the target website in Chrome.  

2. Install "["*Get cookies.txt LOCALLY*"](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc).  
	> "Get cookies.txt LOCALLY" works in other Chromium-based browsers (e.g., Edge).

3. Use the extension to create a cookie file and save it in a safe folder with no access restrictions.  
	>For detailed extraction methods, see the next chapter. ([simple method](#simple-method--add-websites-one-by-one) and [stable method](#stable-method--prevent-interference-with-browser))  

4. In the extension’s configuration file, set the "*cookie\_file*" key in the \[COOKIE] section to the cookie file you saved:  
	>This cookie file is updated by yt-dlp.exe each time it is used.  
	>Example 1  
	>```
	>cookie_file=C:\MyData 2025 3\♨secret☹\cookie2503.txt
	>```
	>  
	>Example 2  
	>```
	>  
	>cookie_file=%APPDATA%\PotPlayerMini64\Extension\Media\PlayParse\cookies01.txt
	>```

#### Simple method – add websites one by one

1. Open and log in to the target site in Chrome.  

2. Use **Export As** in the extension to save its cookies.  

3. For multiple sites, repeat and merge into one file.  

If you log out in your browser, these cookies become invalid and must be re-extracted.  
For independent cookies unaffected by your browser’s logout status, use the next stable method.  

When saving a cookie file, the **\[Export All Cookies]** button collects all browser cookies in a single step.  
However, this is not recommended for security reasons, as it may include cookies from unrelated sites, such as financial services.  
While this button is also used in the next “stable method”, it only collects cookies limited to the sessions of a temporary incognito/private window in that case.  

#### Stable method – prevent interference with browser

Uses a browser’s Incognito window to store all necessary cookies independently.  

**An Incognito window** is also called **a Private window** or **an InPrivate window**, depending on the browser.  

1. Open the details of "*Get cookies.txt LOCALLY*" from Chrome’s extension settings and enable it to run in Incognito mode.  

2. Open a Chrome Incognito window.  
	> The Incognito window can be opened via the menu button at the top right of the browser.  
	> To prevent unnecessary cookies, keep options like "Block third-party cookies" or "Enhanced tracking prevention" enabled.  

3. Open the target websites one by one in the Incognito window, log in to your accounts on each site, then close their tabs.  
	> Do not close the Incognito window itself, close only the individual website tabs.  
	> To avoid the Incognito window closing automatically, open a new tab before closing a website tab.  
	> Make sure not to log out of the websites; simply close the tabs while logged in.  

4. In the Incognito window, open "*Get cookies.txt LOCALLY*" and click the \[**Export All Cookies**] button to save cookies from all the opened websites into a single file.  
	> This file will include cookies for every website opened in step 3.  

5. Close the Incognito window.  
	> Closing the Incognito window discards its cookies from the browser,  
	> leaving only the copied cookies and associated tokens for yt-dlp.  

This method creates cookies with tokens separate from your browser, reducing possible conflicts.  

#### For Firefox

Firefox also supports manual cookie extraction via its add-on [cookies.txt](https://addons.mozilla.org/firefox/addon/cookies-txt/).  

With the "simple method" above, you can choose which container’s cookies to export if using [Multi-Account Containers](https://support.mozilla.org/kb/containers).  

With the "stable method" above. PotPlayer/yt-dlp will not be affected by the Firefox's login status.  

#### Additional Notes

Unless you log out, cookies usually last for months, but they can expire or be invalidated at any time.  
If that happens, recreate the cookie file.  

## History

* 2025-03-16 Published.  

