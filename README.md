﻿﻿
# Parse Streaming with yt-dlp - PotPlayer Extension

## Overview

***The yt-dlp extension*** for **PotPlayer** includes an AngelScript file that enables PotPlayer to play streaming videos or audio tracks from a variety of websites.  
With this yt-dlp extension, when opening a URL, PotPlayer temporarily runs yt-dlp.exe to obtain a playable link.  

The supported websites and services are largely the same as those supported by yt-dlp.exe, with some exceptions.  
As a general rule, yt-dlp does not support sites that are obviously pirated.  
It also cannot be expected to handle paid content (usually protected with DRM).  
However, if it is DRM-free, yt-dlp can sometimes access it by logging in with a paid account.  

For YouTube, PotPlayer can generally play YouTube videos without this extension,  
but it can be useful when YouTube restricts access from external applications.  
Although YouTube sometimes requires users to log in, PotPlayer has no built-in login feature for standard playback.  
This extension uses yt-dlp to handle web cookies and login authentication, allowing PotPlayer to bypass certain restrictions.  

## Requirements

PotPlayer is a Windows-only media player, so this extension is intended for use on Windows.  

The following applications are **not** included in this repository. Please obtain them separately.  

* [PotPlayer (**250226 or later**)](https://potplayer.tv/)  
	Development versions are available in the [developer community](https://cafe.daum.net/pot-tool) (Korean).  
	Using Google Translate on this site may cause reload errors.  

* [yt-dlp.exe](https://github.com/yt-dlp/yt-dlp/)  
	*yt-dlp.exe* also provides nightly builds.  
	See [Updating yt-dlp](#updating-yt-dlpexe).  

Always using the latest versions is recommended for proper website support.  

In addition, you may need the following commands:  

* [deno.exe](https://github.com/denoland/deno) -- Required for full YouTube support  
	At present, **yt-dlp** cannot fully support YouTube without an external JavaScript runtime such as **deno**.  
	See: https://github.com/yt-dlp/yt-dlp/issues/15012  
	When using **deno**, download ***deno-x86_64-pc-windows-msvc.zip*** from the release page.  
	Then place the extracted *deno.exe* in the same folder as *yt-dlp.exe*.  

* [curl.exe](https://curl.se/windows/) -- Used to retrieve server data  
	Some features of this extension do not work without **curl**.  
	**On windows versions earlier than 10, manual setup is required** (Windows 10 and later include **curl** by default).  
	Place *curl.exe* in the *system32* folder or in any folder included in the system PATH.  

## Installation

Follow these steps to install this extension.  
Make sure that PotPlayer is installed in advance.  

1. Download *Source code (zip)* from the Assets section of the release page.  
   >  
   > ![Set yt-dlp extension 0](https://github.com/user-attachments/assets/c22660f0-64f0-4152-b1a0-5c2f1394d758)  

2. Extract the downloaded files to the script folder.  
   `(PotPlayer installation folder)\Extension\Media\PlayParse\`  
   > ![Set yt-dlp extension 1](https://github.com/user-attachments/assets/91725632-5821-4356-9159-1e93603e2db5)  
   >  
   > ***MediaPlayParse - yt-dlp.as*** and ***yt-dlp_default.ini*** are required.  
   > You must always update *yt-dlp_default.ini* at the same time as *MediaPlayParse - yt-dlp.as*.  
   > You can customize the icon of *MediaPlayParse - yt-dlp.as* with the *.ico files renamed.  
   > ***yt-dlp_radio1.jpg*** and ***yt-dlp_radio2.jpg*** are thumbnails for online radio, displayed in the PotPlayer's playlist panel.  
   >Other files in the repository are not required in this folder.

3. Place *yt-dlp.exe* in PotPlayer's module folder:  
    `(PotPlayer installation folder)\Module\`  
   > ![Set yt-dlp extension 2](https://github.com/user-attachments/assets/10784fac-9397-40a8-8205-72208c5f28fa)  
   >  
   > You can change this folder using the ***ytdlp_location*** setting in the [MAINTENANCE] section of the configuration file.  
   > Also place ***deno.exe*** in the same folder as *yt-dlp.exe* to ensure proper YouTube support.  
   > If *yt-dlp.exe* is not found, this script will return an error.  

4. Confirm that **yt-dlp** appears in PotPlayer's extension list:  
   `Preferences (F5) > Extensions > Media Playlist/Playitem`  
   > ![2025-03-16\_02h02\_06](https://github.com/user-attachments/assets/e4aa7177-7ba3-4f8a-8373-dbdd0d83f091)
   >  
   > If not visible, click [**Reload files**] or restart PotPlayer.  
   > Also verify the extension detects the version of ***yt-dlp.exe*** in the **info** panel.  
   >  
   > ![2025-03-16\_02h06\_39](https://github.com/user-attachments/assets/fa517e1c-e837-4326-aff1-c4255994c96b)

5. Try opening URLs from various online video/audio services using PotPlayer.  
   > ![Open URLs](https://github.com/user-attachments/assets/edee7d70-eb46-462e-a26c-aef92f4842ea)  

## Tune-up

### Extension Priority

When multiple extensions are enabled, the higher one in the list takes priority.  
For YouTube, if you prefer PotPlayer’s built-in YouTube extension over this one,
move **yt-dlp** below **YouTube** using the Up/Down buttons in the **Media Playlist/Playitem** setting.  
PotPlayer’s built-in YouTube extension generally starts playback faster.  
If the preferred extension fails to process a URL, the task is passed to the next extension.  

![2025-08-14\_22h01\_22](https://github.com/user-attachments/assets/27bc5fc6-1fc5-42e8-aa1f-9d4059649216)

### Configuration File

You can customize the behavior by editing the *yt-dlp.ini* configuration file.  
Open it in a popup panel via the [**Config file**] button that appears when you select **yt-dlp** in the extension settings list.  
Some features, including account login and automatic *yt-dlp.exe* updates, are controlled here.  
Each setting has a description inside the file.  

![2025-08-14\_22h23\_34](https://github.com/user-attachments/assets/e91f9bdf-af11-4397-930a-b4ce2726e21f)

Available keys are predefined and always visible in the *yt-dlp.ini* panel.  
To reset keys or sections, delete them from the file — they will be restored with default values automatically.  
You can comment out lines by adding "//" at the start (different from standard INI syntax, designed for better visibility).  
Lines detected as comments are automatically prefixed with "//".  

There are also “hidden keys” that are not normally listed in *yt-dlp.ini* but appear in *yt-dlp_default.ini* with a “#” prefix.  
To use these keys, add them to *yt-dlp.ini* without the “#” and set their values there (You should not edit *yt-dlp_default.ini* directly).  

You can reorder sections in *yt-dlp.ini* as you like.  
For example, move the frequently used the [MAINTENANCE] section near the top by cutting and pasting.  
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

## Notes

### Process Not Responding

After PotPlayer invokes *yt-dlp.exe* through the yt-dlp extension. it takes some time to obtain the available links.  
When extracting a large playlist, the import may take several minutes to complete.  
If necessary, adjust the timeout settings in the [TARGET] section of the configuration file, especially ***playlist_metadata_timeout***.  
Aside from this, *yt-dlp.exe* may occasionally hang due to failed connections to the target server or errors in interpreting the URL content.  

In these situations, PotPlayer will remain stuck in the “*preparing to play*” state.  
If the playback does not start even after waiting, press PotPlayer's Stop button to halt the loading process.  
Next, check whether any *yt-dlp.exe* processes are still running in the background.  
If any are found, terminate them forcibly to prevent unnecessary resource usage.  
However, if yt-dlp.exe is not actually hanging and is only taking a long time to process, its process will eventually terminate automatically.  

Note that PotPlayer or yt-dlp cannot forcibly terminate these processes on their own.  
You will need to use your system’s **Task Manager** or, preferably, a more user-friendly external tool such as [Process Explorer](https://learn.microsoft.com/sysinternals/downloads/process-explorer) or [System Explorer](https://systemexplorer.net/).  

<img width="959" height="475" alt="2025-08-15\_21h14\_42" src="https://github.com/user-attachments/assets/6afc599a-1f96-4091-993f-40dad6b4071f" />

It’s a basic shortcoming that you have to monitor processes with an external tool.  
This comes from server restrictions, faulty processing of *yt-dlp.exe* and limitations in the design of the PotPlayer extension.  

### Option Selection Criteria

PotPlayer generally plays only direct links to media content, with some exceptions.  
For websites other than YouTube and KakaoTV, yt-dlp must basically support them.  
Even when using the yt-dlp extension, PotPlayer cannot play media content from sites or pages that yt-dlp does not support.  

|                                                 | YouTube                                       | non-YouTube sites        |
| --------------------------------------- | ------------------------------------------ | --------------------------- |
| Default PotPlayer (built-in)           | normal viewing                              | not available                |
| yt-dlp extention                          | when default is restricted                | regular content            |
| yt-dlp extention +login                | login-only content / when restricted | login-only content          |
| yt-dlp extention +login +poToken | when strongly restricted                 | (ignore poToken)           |
| Internet Brower (Chrome etc.)      | most reliable for viewing                | most reliable for viewing |

Although it is not shown in this table, PotPlayer can also play **KakaoTV** by default.  

For login, see [Get Cookies and Login](#get-cookies-and-login).  
For poToken, see [PO Token Guide](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide) and specify it in the extension's configuration file.  

In its default method of accessing YouTube, PotPlayer does not require cookies or login.  
However, PotPlayer includes built-in workarounds that can bypass some YouTube restrictions more effectively than using the yt-dlp extension without cookies.  

It may seem that the lower options in this table are always superior for viewing capability, but sometimes you may not be able to play YouTube with login even though playback works without login.  
This depends on which connections YouTube is restricting at that time.  

>If you cannot play videos in a certain site after logging in, try logging out of the site, clearing cookies for that site in your browser, and then logging in again.  
>If you use a cookie file, recreate it from the same browser after logging in again.  

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

In the extension’s configuration file, set the "*cookie_browser*" key in the [COOKIE] section like this:  

```
cookie_browser=firefox
```

Once logged in with Firefox, you can watch login-required content in PotPlayer/yt-dlp.  
After creating login cookies, you can close Firefox and use PotPlayer.  
But Keep the site logged in when closing Firefox. Also disable any settings that delete cookies when closing Firefox.  

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

4. In the extension’s configuration file, set the "*cookie_file*" key in the [COOKIE] section to the cookie file you saved:  
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

When saving a cookie file, the **[Export All Cookies]** button collects all browser cookies in a single step.  
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

4. In the Incognito window, open "*Get cookies.txt LOCALLY*" and click the [**Export All Cookies**] button to save cookies from all the opened websites into a single file.  
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

## Extracting Playlists

### Support for Website Playlists

Each website may provide its own playlist features.  
PotPlayer can extract YouTube playlists by default, and this extension adds support for playlists from many other sites — including YouTube.  
When you open a playlist URL, the yt-dlp extension will import its items into PotPlayer’s playlist if yt-dlp supports that playlist.  

While website playlists vary widely, yt-dlp only supports limited types.  
Moreover, small playlists may load completely, but large ones may fail to load fully even after a long wait.

### Playlist or Single Video

For YouTube, some URLs contain both a single video and a playlist (e.g., https://www.youtube.com/watch?v=XXXXX&list=YYYYY) and may not look like playlists at first glance.  
PotPlayer treats these as playlists by default, but this extension does not.  
Therefore, enabling the YouTube playlist processing in this extension helps prevent unintended imports of a large number of videos all at once.  
In that case, if you want to treat a certain YouTube URL as a playlist, make sure that the URL includes only a playlist ID without any video ID (e.g., https://www.youtube.com/playlist?list=YYYYY).  

For various websites including YouTube, you can set playlist handling (if supported) in the [TARGET] section of the configuration file.

### External Playlist Albums

In PotPlayer, a playlist in its own format is called an **album**.  
As with YouTube, this extension also allows you to create an album as an "***external playlist***" from a playlist URL on non-YouTube websites.  
An "*external playlist*" is automatically updated with the latest streaming content whenever you click its album tab to bring it into focus in the playlist panel.  

![2025-08-15\_03h58\_09](https://github.com/user-attachments/assets/27ebd5fe-de63-449a-9ca1-a5eb2aaefa5e)

(For YouTube, the yt-dlp extension is not required to use an external-playlist album.)

## SponsorBlock on YouTube

This extension supports [SponsorBlock](https://sponsor.ajay.app/) starting from version 251213.  
You can skip sponsor segments in YouTube videos using SponsorBlock chapters.  
These chapters are submitted by general viewers using web browsers or other applications with their support SponsorBlock.  
(If a video has no submitted chapters, this method of skipping is not available for that video.)  

These sponsored or promotional segments are parts of the video itself.  
If a video already contains its own chapters, they will be partially overwritten by SponsorBlock chapters.  

SponsorBlock provides various categories in addition to *sponsor*.  
Below is a complex chapter example ([page](https://www.youtube.com/watch?v=4Y4w5OspCDs#requiredSegment=8b288d470b4f8229e478825c2d21070e6bbdb9bc0f03d8ec12879b86d512a7b67)):  

![2025-12-21_04h15_00](https://github.com/user-attachments/assets/b07802a9-6f30-4604-85da-c9271b311eef)

SponsorBlock chapters have the prefix `<SB` in their titles, which is added by this yt-dlp extension.  

### Categories

Available categeries (See [the SponsorBlock Guidelines](https://wiki.sponsor.ajay.app/w/Guidelines)) :
|Category (`SponsorBlock`)|Category (`yt-dlp`)|Chapter Title (`yt-dlp Extension`)|
| ---- | ---- | ---- |
|[`Highlight`](https://wiki.sponsor.ajay.app/w/Highlight)|**`poi_highlight`**|`<SB-Highlight>`|
|[`Sponsor`](https://wiki.sponsor.ajay.app/w/Sponsor)|**`sponsor`**|`<SB/Sponsor>`|
|[`Interaction Reminder (Subscribe)`](https://wiki.sponsor.ajay.app/w/Interaction_Reminder_(Subscribe))|**`interaction`**|`<SB/Interaction Reminder>`|
|[`Unpaid/Self Promotion`](https://wiki.sponsor.ajay.app/w/Unpaid/Self_Promotion)|**`selfpromo`**|`<SB/Unpaid/Self Promotion>`|
|[`Tangents/Jokes`](https://wiki.sponsor.ajay.app/w/Tangents/Jokes)|**`filler`**|`<SB/Filler Tangent>`|
|[`Hook/Greetings`](https://wiki.sponsor.ajay.app/w/Hook/Greetings)|**`hook`**|`<SB/Hook/Greetings>`|
|[`Preview/Recap`](https://wiki.sponsor.ajay.app/w/Preview/Recap)|**`preview`**|`<SB/Preview/Recap>`|
|[`Intermission/Intro Animation`](https://wiki.sponsor.ajay.app/w/Intermission/Intro_Animation)|**`intro`**|`<SB/Intermission/Intro Animation>`|
|[`Endcards/Credits`](https://wiki.sponsor.ajay.app/w/Endcards/Credits)|**`outro`**|`<SB/Endcards/Credits>`|
|[`Music: Non-Music Section`](https://wiki.sponsor.ajay.app/w/Music:_Non-Music_Section)|**`music_offtopic`**|`<SB/Non-Music Section>`|

Most of the category names in SponsorBlock differ from those used by yt-dlp due to changes across versions.  

Each category has a priority in this yt-dlp extension.  
**Categories listed higher in the table have higher priority.**  

To enable SponsorBlock in the yt-dlp extension, set the desired yt-dlp categories using the ***sponsor_block*** setting in the [YOUTUBE] section of the configuration file:  
```
sponsor_block=sponsor, interaction, selfpromo, music_offtopic
```
To use all categories, use ***all*** :  
```
sponsor_block=all
```
To exclude specific categories, prefix them with a minus sign (-) :  
```
sponsor_block=all, -preview, -filler
```

>Be careful with category priorities when configuring this setting.  
>For example, ***music_offtopic*** chapters in music videos often cover relatively large areas of the video and may overlap with other categories.  
>As a result, they may be overwritten by higher-priority chapters (such as *intro* or *outro*) and become invisible when using *all* as categories.  

>Unlike other categories, ***poi_highlight*** is not intended to serve as a chapter but a single point marking the beginning of an important section.  
>In PotPlayer, it is displayed as a very short one-second chapter and is not used for skipping video segments.  

### Skip Feature in PotPlayer

In PotPlayer, any chapter can be skipped using the following commands.  
- ***Next Bookmark/Chapter*** : Shift+PgDn (default key, configurable)  
- ***Prev Bookmark/Chapter*** : Shift+PgUp (default key, configurable)  

In addition, PotPlayer provides an **auto-skip feature** that automatically skip chapters/bookmarks with specified titles.  
This is especially useful for SponsorBlock chapters.  

To configure auto-skip, open the *Skip Setup* dialog:  
> PotPlayer's main menu (right click the main window) > Playback > Skip > Skip Setup

![2025-12-21_03h28_13](https://github.com/user-attachments/assets/9158989e-a395-49af-960a-bb6394396e1c)

Then configure the following settings:  
1. *Enable skip feature* > On  
2. *Chapter title* > On  
3. Enter target strings in the chapter field  

The specified strings must appear in the chapter titles you want to skip.  
Multiple strings can be separated by semicolons (;).  
Note that **a space after the semicolon is not allowed here**.  

Example:  

```
SB/Sponsor;SB/Unpaid;SB/Interaction
```

To match all SponsorBlock chapters at once (except for *Highlight*):  

```
<SB/
```

This matching is case-insensitive.  

## History

* 2025-03-16 Published.  


