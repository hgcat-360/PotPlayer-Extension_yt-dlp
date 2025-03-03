/**********************************************************
    Parse Streaming by yt-dlp
***********************************************************
    
    Extension for PotPlayer 250226 or later versions
    Placed in \PotPlayer\Extension\Media\PlayParse\
***********************************************************/

string SCRIPT_VERSION = "250303";

string YTDLP_EXE = "Module\\yt-dlp.exe";
	//yt-dlp executable file; relative path to HostGetExecuteFolder(); (required)

string SCRIPT_CONFIG = "Extension\\Media\\PlayParse\\yt-dlp.ini";
	//configuration file; relative path to HostGetConfigFolder()
	//created automatically by this script

string SCRIPT_CONFIG_DEFAULT = "yt-dlp_default.ini";
	//default configuration file; placed in HostGetScriptFolder(); (required)

string RADIO_IMAGE_1 = "yt-dlp_radio1.jpg";
string RADIO_IMAGE_2 = "yt-dlp_radio2.jpg";
	//radio image files; placed in HostGetScriptFolder()


class CFG
{
	array<string> sections = {
		"Switch",
		"Cookie",
		"YouTube",
		"Target",
		"Format",
		"Network",
		"Maintenance"
	};
	
	//[Switch]
	int stop;
	
	//[Cookie]
	string cookie_file;
	string browser_name;
	int mark_watched;
	
	//[YouTube]
	int enable_youtube;
	int no_youtube_live;
	string base_lang;
	int live_from_start;	//hidden (not recommended)
	string potoken_direct;
	string potoken_bgutil_script;	//hidden
	string potoken_bgutil_baseurl;	//hidden
	
	//[Target]
	int website_playlist;
	int hotlink_media_file;
	int hotlink_playlist_file;
	int radio_thumbnail;
	
	//[Format]
	int reduce_low_quality;
	int remove_duplicated_quality;
	
	//[Network]
	string proxy;
	int ipv;
	int no_check_certificates;
	
	//[Maintenance]
	int console_out;
	int update_ytdlp;	//hidden if critical error
	int critical_error;	//hidden if no critical error
	string ytdlp_hash;
	
	string baseLang;
	
	bool isAlert = false;
	bool isDefaultError = false;
	bool isSaveError = false;
	
	string BOM_UTF8 = "\xEF\xBB\xBF";
	string BOM_UTF16LE = "\xFF\xFE";
	
	string _changeToUtf8Basic(string str, string &out code)
	{
		//change to utf8 without top BOM
		if (str.find(BOM_UTF8) == 0)
		{
			code = "utf8_bom";
			str = str.substr(BOM_UTF8.size());
		}
		else if (str.find(BOM_UTF16LE) == 0)
		{
			code = "utf16_le";
			str = str.substr(BOM_UTF16LE.size());
			str = HostUTF16ToUTF8(str);
		}
		else
		{
			//consider codes only as utf8 or utf16le
			code = "utf8";
		}
		return str;
	}
	
	string _changeFromUtf8Basic(string str, string code)
	{
		if (code == "utf8_bom")
		{
			str = BOM_UTF8 + str;
		}
		else if (code == "utf16_le")
		{
			str = HostUTF8ToUTF16(str);
			str = BOM_UTF16LE + str;
		}
		else{
			//consider codes only as utf8 or utf16le
		}
		return str;
	}
	
	bool _createFolder(string folder)
	{
		//this folder is relative to HostGetConfigFolder()
		//it doesn't includ a file name
		if (HostFolderExist(HostGetConfigFolder() + folder)) return true;
		if (folder.empty()) return false;
		
		int pos = folder.findLast("\\");
		string folderParent = (pos >= 0) ? folder.Left(pos) : "";
		if (_createFolder(folderParent))
		{
			return HostFolderCreate(folder);
		}
		return false;
	}
	
	uintptr _createFolderFile(string path)
	{
		//this path is relative to HostGetConfigFolder()
		//it includs a file name
		string folder = path;
		int pos = folder.findLast("\\");
		folder = (pos >= 0) ? folder.Left(pos) : "";
		if (_createFolder(folder))
		{
			return HostFileCreate(path);
		}
		return 0;
	}
	
	string _readFileDefault(string &out code)
	{
		string str;
		string path = HostGetScriptFolder() + SCRIPT_CONFIG_DEFAULT;
		uintptr fp = HostFileOpen(path);
		if (fp > 0)
		{
			isDefaultError = false;
			str = HostFileRead(fp, HostFileLength(fp));
			HostFileClose(fp);
			str = _changeToUtf8Basic(str, code);
		}
		else
		{
			isDefaultError = true;
			if (isAlert)
			{
				isAlert = false;
				string msg =
				"The following default config file is not found.\r\n"
				"Please place it together with the script file;\r\n\r\n"
				+ HostGetScriptFolder() + "\r\n"
				+ SCRIPT_CONFIG_DEFAULT;
				HostMessageBox(msg, "[yt-dlp] Default config file error", 0, 0);
			}
			code = "utf8_bom";
		}
		return str;
	}
	
	string _readFileDefault()
	{
		string code;
		return _readFileDefault(code);
	}
	
	string _openFile(uintptr &out fp, string &out code)
	{
		string str;
		fp = _createFolderFile(SCRIPT_CONFIG);
		if (fp > 0)
		{
			str = HostFileRead(fp, HostFileLength(fp));
			if (str.size() > 10)
			{
				str = _changeToUtf8Basic(str, code);
			}
			else
			{
				str = _readFileDefault(code);
			}
		}
		else
		{
			str = _readFileDefault(code);
		}
		return str;
	}
	
	int _closeFile(uintptr fp, bool isWrite, string str, string code)
	{
		int writeState = 0;
		if (fp > 0)
		{
			if (isWrite)
			{
				str = _changeFromUtf8Basic(str, code);
				if (HostFileSetLength(fp, 0) == 0)
				{
					if (uint(HostFileWrite(fp, str)) == str.size()) writeState = 2;
				}
			}
			else
			{
				writeState = 1;
			}
			HostFileClose(fp);
		}
		else
		{
			writeState = -1;
		}
		return writeState;
	}
	
	int _getLastPos(string str)
	{
		//get last position to edit (not end of string)
		int pos = str.findLastNotOf("\r\n");
		if (pos < 0) return str.size();
		int lf = 0;
		for (pos += 1; uint(pos) < str.size(); pos++)
		{
			if (str.substr(pos, 1) == "\n")
			{
				lf++;
				if (lf > 2) break;
			}
		}
		return pos;
	}
	
	int _searchSectionTop(string str, string section, int from = 0)
	{
		int top = -1;
		if (!str.empty())
		{
			section.MakeLower(); str.MakeLower();
			section = "[" + section + "]";
			if (from == 0 && str.Left(section.size()) == section) top = 0;
			else
			{
				if (from > 0) from -= 1;
				top = str.find("\n" + section, from);
				if (top >= 0) top += 1;
			}
		}
		return top;
	}
	
	int _searchBlankLine(string str, int from = 0)
	{
		if (!str.empty())
		{
			int n = 0;
			for (uint pos = from; pos < str.size(); pos++)
			{
				string c = str.substr(pos, 1);
				if (c == "\n")
				{
					n++;
					if (n > 1) return pos + 1;
				}
				else if (c != "\r")
				{
					n = 0;
				}
			}
		}
		return -1;
	}
	
	bool _deleteSectionArea(string &inout str, string section, int &inout topExcept)
	{
		bool isDel = false;
		int top = 0;
		int end;
		while (true)
		{
			top = _searchSectionTop(str, section, top);
			if (top < 0) break;
			end = str.find("\n[", top);
			if (end > 0) end += 1;
			else end = _getLastPos(str);
			int len = end - top;
			if (top != topExcept)
			{
				str.erase(top, len);
				if (topExcept > top + len) topExcept -= len;
				else if (topExcept > top) topExcept = top;
				isDel = true;
			}
			else top = end;
		}
		return isDel;
	}
	
	bool _deleteSectionArea(string &inout str, string section)
	{
		int top = -1;
		return _deleteSectionArea(str, section, top);
	}
	
	string _getSectionArea(string &inout str, string section, int &out top)
	{
		string sectArea;
		top = _searchSectionTop(str, section);
		if (top >= 0)
		{
			int end = str.find("\n[", top);
			if (end > 0) end += 1; else end = _getLastPos(str);
			sectArea = str.substr(top, end - top);
		}
		return sectArea;
	}
	
	void _setSections(string &inout str)
	{
		int top1 = 0;
		for (uint i = 0; i < sections.size(); i++ )
		{
			int top2 = top1;
			string sectArea = _getSectionArea(str, sections[i], top2);
			if (top2 >= 0)
			{
				if (top2 > top1)
				{
					str.insert(top1, sectArea);
				}
				
				//delete duplicated section if exists
				_deleteSectionArea(str, sections[i], top1);
			}
			else
			{
				//Add the missing section
				top1 = _getLastPos(str);
				sectArea = "[" + sections[i] + "]\r\n\r\n";
				str.insert(top1, sectArea);
			}
			top1 += sectArea.size();
		}
		if (uint(top1) < str.size())
		{
			str.erase(top1);
		}
	}
	
	bool _deleteKeyArea(string &inout str, string key, int &inout topExcept)
	{
		//delete all areas of the key in spite of section
		bool isDel = false;
		string _str = str;
		int top = 0;
		array<dictionary> dicsMatch;
		while (HostRegExpParse(_str, "^[^\t\r\n]*\\b" + key + " *=", dicsMatch))
		{
			int _top, _end;
			string s1, s2;
			dicsMatch[0].get("first", s1);
			dicsMatch[0].get("second", s2);
			_top = _str.size() - s2.size() - s1.size();
			_end = _searchBlankLine(_str, _top);
			int sepa = _str.find("\n[", _top);
			if (sepa > 0) sepa += 1; else sepa = _getLastPos(_str);
			if (_end < 0 || _end > sepa) _end = sepa;
			int len = _end - _top;
			top += _top;
			if (top != topExcept)
			{
				str.erase(top, len);
				if (topExcept > top + len) topExcept -= len;
				else if (topExcept > top) topExcept = top;
				isDel = true;
			}
			else
			{
				top += len;
			}
			_str = str.substr(top);
		}
		return isDel;
	}
	
	bool _deleteKeyArea(string &inout str, string key)
	{
		int top = -1;
		return _deleteKeyArea(str, key, top);
	}
	
	string _getKeyArea(string &inout str, string section, string key, int &out top, bool &inout isAddNew)
	{
		string keyArea;
		string sectArea = _getSectionArea(str, section, top);
		if (!sectArea.empty())
		{
			array<dictionary> dicsMatch;
			if (HostRegExpParse(sectArea, "^[^\t\r\n]*\\b" + key + " *=", dicsMatch))
			{
				string s1, s2;
				dicsMatch[0].get("first", s1);
				dicsMatch[0].get("second", s2);
				int _top = sectArea.size() - s2.size() - s1.size();
				int _end = _searchBlankLine(sectArea, _top);
				if (_end < 0) _end = _getLastPos(sectArea);
				int len = _end - _top;
				keyArea = sectArea.substr(_top, len);
				top += _top;
				_deleteKeyArea(str, key, top);	//delete duplicated key area if exists
				isAddNew = false;
			}
			else
			{
				if (isAddNew)
				{
					//Add the missing key area from the default config file
					string strDef = _readFileDefault();
					keyArea = _getKeyArea(strDef, section, key);
					if (keyArea.empty()) keyArea = key + "=\r\n\r\n";
					top += sectArea.size();
					str.insert(top, keyArea);
				}
				else
				{
					top = -1;
				}
			}
		}
		else
		{
			top = -1;
			isAddNew = false;
		}
		return keyArea;
	}
	
	string _getset(string &inout str, string section, string key, int opr, string valueSet = "")
	{
		//opr
		//	0: get without adding a new section/key to str
		//	1: get	2: set
		
		string valueOut;
		array<string> patterns = {
			"^[^\t\r\n]+\\b" + key + " *=",	//comment out
			"^" + key + "=([ \t]*)",	//empty value
			"^" + key + "=( *\\S[^\t\r\n]*)"	//specified value
		};
		int top;
		bool isAddNew = opr > 0;
		string keyArea = _getKeyArea(str, section, key, top, isAddNew);
		if (!keyArea.empty())
		{
			int topKey = top;
			int state;
			for (state = 2; state >= 1; state--)
			{
				array<dictionary> dicsMatch;
				if (HostRegExpParse(keyArea, patterns[state], dicsMatch))
				{
					dicsMatch[1].get("first", valueOut);
					string s1, s2;
					dicsMatch[0].get("first", s1);
					dicsMatch[0].get("second", s2);
					topKey += keyArea.size() - s2.size() - s1.size();
					if (opr == 2)
					{
						int endKey = topKey + s1.size();
						str = str.Left(topKey) + key + "=" + valueSet + str.substr(endKey);
					}
					break;
				}
			}
			if (opr == 2 && state == 0)
			{
				str.insert(topKey, key + "=" + valueSet);
			}
			{
				//comment out duplicated keys if exists in key area
				string _str = keyArea;
				int _top = top;
				array<dictionary> dicsMatch;
				while (HostRegExpParse(_str, "^ *" + key + " *=", dicsMatch))
				{
					string s1, s2;
					dicsMatch[0].get("first", s1);
					dicsMatch[0].get("second", s2);
					_top += _str.size() - s2.size() - s1.size();
					if (_top != topKey || state == 0)
					{
						str.insert(_top, "//");
						if (topKey >= _top) topKey += 2;
						_top += 2;
					}
					_top += s1.size();
					_str = s2;
				}
			}
		}
		valueOut.Trim();
		if (valueOut.empty() && !isAddNew)
		{
			//default value is fetched from the default configuration file
			string strDef = _readFileDefault();
			keyArea = _getKeyArea(strDef, section, key);
			if (!keyArea.empty())
			{
				array<dictionary> dicsMatch;
				if (HostRegExpParse(keyArea, patterns[2], dicsMatch))
				{
					dicsMatch[1].get("first", valueOut);
					valueOut.Trim();
				}
			}
		}
		return valueOut;
	}
	
	string _getString(string &inout str, string section, string key, bool isAdd = true)
	{
		string valueGet = _getset(str, section, key, isAdd ? 1 : 0);
		return valueGet.Trim("\"");
	}
	
	int _getInt(string &inout str, string section, string key, bool isAdd = true)
	{
		string valueGet = _getset(str, section, key, isAdd ? 1 : 0);
		return parseInt(valueGet);
	}
	
	string _getKeyArea(string &inout str, string section, string key)
	{
		bool isAddNew = false;
		return _getKeyArea(str, section, key, 0, isAddNew);
	}
	
	string _setString(string &inout str, string section, string key, string valueSet)
	{
		string valuePrev = _getset(str, section, key, 2, valueSet);
		return valuePrev.Trim("\"");
	}
	
	int _setInt(string &inout str, string section, string key, int valueSet)
	{
		string valuePrev = _getset(str, section, key, 2, formatInt(valueSet));
		return parseInt(valuePrev);
	}
	
	bool setString(string section, string key, string valueSet)
	{
		uintptr fp; string code;
		string str0 = _openFile(fp, code);
		string str = str0;
		_setString(str, section, key, valueSet);
		int writeState = _closeFile(fp, str != str0, str, code);
		return writeState > 0;
	}
	
	bool setInt(string section, string key, int valueSet)
	{
		uintptr fp; string code;
		string str0 = _openFile(fp, code);
		string str = str0;
		_setInt(str, section, key, valueSet);
		int writeState = _closeFile(fp, str != str0, str, code);
		return writeState > 0;
	}
	
	void loadFile()
	{
		uintptr fp; string code;
		string str0 = _openFile(fp, code);
		string str = str0;
		
		{
			_setSections(str);
			
			stop = _getInt(str, "Switch", "stop");
			cookie_file = _getString(str, "Cookie", "cookie_file");
			browser_name = _getString(str, "Cookie", "browser_name");
			mark_watched = _getInt(str, "Cookie", "mark_watched");
			enable_youtube =_getInt(str, "YouTube", "enable_youtube");
			no_youtube_live =_getInt(str, "YouTube", "no_youtube_live");
			base_lang = _getString(str, "YouTube", "base_lang");
			live_from_start =_getInt(str, "YouTube", "live_from_start", false);	//hidden
			potoken_direct = _getString(str, "YouTube", "potoken_direct");
			potoken_bgutil_script = _getString(str, "YouTube", "potoken_bgutil_script", false);	//hidden
			potoken_bgutil_baseurl = _getString(str, "YouTube", "potoken_bgutil_baseurl", false);	//hidden
			website_playlist =_getInt(str, "Target", "website_playlist");
			hotlink_media_file =_getInt(str, "Target", "hotlink_media_file");
			hotlink_playlist_file =_getInt(str, "Target", "hotlink_playlist_file");
			radio_thumbnail =_getInt(str, "Target", "radio_thumbnail");
			reduce_low_quality =_getInt(str, "Format", "reduce_low_quality");
			remove_duplicated_quality =_getInt(str, "Format", "remove_duplicated_quality");
			proxy = _getString(str, "Network", "proxy");
			ipv =_getInt(str, "Network", "ipv");
			no_check_certificates =_getInt(str, "Network", "no_check_certificates");
			console_out =_getInt(str, "Maintenance", "console_out");
			critical_error =_getInt(str, "Maintenance", "critical_error", false);	//hidden
			if (critical_error == 0) _deleteKeyArea(str, "critical_error");
			if (critical_error == 0 && ytd.error == 0)
			{
				update_ytdlp =_getInt(str, "Maintenance", "update_ytdlp");
			}
			else
			{
				update_ytdlp = 0;
				_deleteKeyArea(str, "update_ytdlp");
			}
			if (fp > 0) ytdlp_hash =_getString(str, "Maintenance", "ytdlp_hash");
		}
		
		if (_closeFile(fp, str != str0, str, code) < 1)
		{
			isSaveError = true;
			if (isAlert)
			{
				isAlert = false;
				string msg =
				"Script can not create or save the config file.\r\n"
				"Plase confirm that this folder is writable;\r\n\r\n"
				+ HostGetConfigFolder() + "Extension\\";
				HostMessageBox(msg, "[yt-dlp] File save error", 0, 0);
			}
		}
		else
		{
			isSaveError = false;
		}
		
		if (base_lang.size() > 1) baseLang = base_lang;
		else baseLang = HostIso639LangName();
	}
};

CFG cfg;

//----------------------- class DFG end -------------------------


class YTDLP
{
	string fileExe = HostGetExecuteFolder() + YTDLP_EXE;
	string version = "";
	array<string> errors = {"(OK)", "(NOT FOUND)", "(LOOKS_DUMMY)", "(CRITICAL ERROR!)"};
	int error = 0;
	
	int checkYtdlpInfo()
	{
		if (error == 3)
		{
			version = ""; return error;
		}
		if (!HostFileExist(fileExe))
		{
			version = ""; error = 1; return error;
		}
		
		FileVersion verInfo;
		if (!verInfo.Open(fileExe))
		{
			version = ""; error = 2; return error;
		}
		else
		{
			bool isCheck = false;
			if (verInfo.GetProductName() != "yt-dlp" || verInfo.GetInternalName() != "yt-dlp")
			{
				isCheck = true;
			}
			if (verInfo.GetOriginalFilename() != "yt-dlp.exe")
			{
				isCheck = true;
			}
			if (verInfo.GetCompanyName() != "https://github.com/yt-dlp")
			{
				isCheck = true;
			}
			if (verInfo.GetLegalCopyright().find("UNLICENSE") < 0 || verInfo.GetProductVersion().find("Python") < 0)
			{
				isCheck = true;
			}
			version = verInfo.GetFileVersion();	//get version
			if (version.empty())
			{
				isCheck = true;
			}
			
			verInfo.Close();
			if (isCheck)
			{
				version = ""; error = 2; return error;
			}
		}
		
		if (!cfg.isSaveError)
		{
			uintptr fp = HostFileOpen(fileExe);
			string data = HostFileRead(fp, HostFileLength(fp));
			HostFileClose(fp);
			string hash = HostHashSHA256(data);
			if (hash.empty())
			{
				version = ""; error = 2; return error;
			}
			else
			{
				if (cfg.ytdlp_hash.empty())
				{
					string msg = "You are using newly placed [yt-dlp.exe].";
					HostMessageBox(msg, "[yt-dlp]", 2, 0);
					cfg.ytdlp_hash = hash;
					cfg.setString("Maintenance", "ytdlp_hash", hash);
				}
				else if (hash != cfg.ytdlp_hash)
				{
					if (error >= 0)
					{
						string msg =
						"Your [yt-dlp.exe] is different from before.";
						HostMessageBox(msg, "[yt-dlp] ALERT", 0, 0);
						error = -1; return error;
					}
					else
					{
						cfg.ytdlp_hash = hash;
						cfg.setString("Maintenance", "ytdlp_hash", hash);
					}
				}
			}
		}
		
		error = 0; return error;
	}
	
	void criticalError()
	{
		version = "";
		error = 3;
		cfg.critical_error = 1;
		cfg.setInt("Maintenance", "critical_error", 1);
		string msg = "Please confirm that your [yt-dlp.exe] is real.\r\n";
		HostPrintUTF8("\r\n[yt-dlp] CRITICAL ERROR! " + msg);
		msg += "It is in Module folder under PotPlsyer's folder.";
		HostMessageBox(msg, "[yt-dlp] CRITICAL ERROR", 0, 2);
	}
	
	void updateVersion()
	{
		if (version.empty()) ytd.checkYtdlpInfo();
		if (error != 0) return;
		HostIncTimeOut(10000);
		string output = HostExecuteProgram(fileExe, " -U");
		{
			int pos = output.findLastNotOf("\r\n");
			if (pos >= 0) output = output.Left(pos + 1);
		}
		HostMessageBox(output, "[yt-dlp] Update yt-dlp.exe", 2, 1);
		error = -1;
		ytd.checkYtdlpInfo();
	}
	
	array<string> _getEntries(const string str, uint &out posLog)
	{
		array<string> entries;
		posLog = 0;
		
		int top = -1;
		if (str.Left(1) == "{") top = 0;
		else top = str.find("\n{", 0);
		
		while (top >= 0)
		{
			if (top > 0) top += 1;
			int end = str.find("}\n", top);
			if (end < 0) break;
			end += 1;
			string entry = str.substr(top, end - top);
			entries.insertLast(entry);
			posLog = end + 1;
			top = str.find("\n{", end);
		}
		
		return entries;
	}
	
	array<string> waitOutputs;
	
	array<string> exec(string url, bool isPlaylist)
	{
		ytd.checkYtdlpInfo();
		if (error != 0) return {};
		
		if (cfg.console_out > 0) HostOpenConsole();
		
		string options = "";
		
		int woi = waitOutputs.find(url);
		
		if (!isPlaylist)	//a single video/audio
		{
			if (woi >= 0 )
			{
				waitOutputs.removeAt(woi);
				if (cfg.console_out > 0) HostPrintUTF8("\r\n[yt-dlp] Unsupported - \"" + url +"\"\r\n");
				return {};
			}
			
			if (cfg.console_out > 0) HostPrintUTF8("\r\n[yt-dlp] Parsing... - \"" + url +"\"\r\n");
			
			options += " -I 1";
			
			//using cookie
			bool isCookie = false;
			if (cfg.cookie_file.size() > 3)
			{
				options = " --cookies \"" + cfg.cookie_file + "\"";
				isCookie = true;
			}
			else if (cfg.browser_name.size() > 3)
			{
				options = " --cookies-from-browser \"" + cfg.browser_name + "\"";
				isCookie = true;
			}
			if (isCookie)
			{
				if (cfg.potoken_bgutil_script.size() > 10)
				{
					options += " --extractor-args \"youtube:getpot_bgutil_script=" + cfg.potoken_bgutil_script + "\"";
				}
				if (cfg.potoken_bgutil_baseurl.size() > 10)
				{
					options += " --extractor-args \"youtube:getpot_bgutil_baseurl=" + cfg.potoken_bgutil_baseurl + "\"";
				}
				if (cfg.potoken_direct.size() > 10)
				{
					options += " --extractor-args \"youtube:po_token=web.gvs+" + cfg.potoken_direct + "\"";
				}
			}
			
			if (cfg.mark_watched == 1) options += " --mark-watched";
			if (cfg.live_from_start == 1) options += " --live-from-start";
		}
		else	//playlist
		{
			if (woi >= 0 ) return {};
			
			if (cfg.console_out > 0) HostPrintUTF8( "\r\n[yt-dlp] Extracting playlist entries... - \"" + url +"\"\r\n");
			
			if (_IsYoutubeUrl(url))
			{
				options += " --flat-playlist";
				//Fastest but collected entries have no title or thumbnail except for youtube.
			}
			
			//Don't use cookie while extracting playlist items.
			
			//For playlist, detailed data is not necessary. (no effect??)
			options += " --skip-download";
			options += " -R 0 --file-access-retries 0 --fragment-retries 0";
			options += " --abort-on-error";
			
			HostIncTimeOut(30000);
		}
		
		options += " --retry-sleep exp=1:10";
		
		if (cfg.proxy.size() > 3) options += " --proxy \"" + cfg.proxy + "\"";
		
		if (cfg.ipv == 4) options += " -4";
		else if (cfg.ipv == 6) options += " -6";
		
		if (cfg.no_check_certificates == 1) options += " --no-check-certificates";
		
		if (cfg.console_out > 1) options += " -v";	//Verbose log
		
		if (cfg.update_ytdlp == 1) options += " -U";
		
		options += " -j --no-playlist --all-subs -- \"" + url + "\"";
			//Note: "-j" must be in lower case.
		
		if (waitOutputs.find(url) < 0)
		{
			if (waitOutputs.size() > 9) waitOutputs.removeAt(0);
			waitOutputs.insertLast(url);
		}
		
		string output = HostExecuteProgram(fileExe, options);
		
		woi = waitOutputs.find(url);
		if (woi >= 0 ) waitOutputs.removeAt(woi);
		
		uint posLog;
		array<string> entries = _getEntries(output, posLog);
		
		if (cfg.console_out == 1)
		{
			string log = output.substr(posLog).TrimLeft("\r\n");
			if (!log.empty()) HostPrintUTF8(log);
		}
		else if (cfg.console_out == 2)
		{
			HostPrintUTF8(output);
		}
		if (entries.size() == 0)
		
		{
			if (output.find("ERROR:") < 0 && output.find("WARNING:") < 0)
			{
				criticalError();
			}
			else
			{
				if (cfg.console_out > 0) HostPrintUTF8("[yt-dlp] Unsupported. - \"" + url +"\"\r\n");
			}
		}
		
		return entries;
	}
};

YTDLP ytd;

//---------------------- class YTDLP end ------------------------


void OnInitialize()
{
	//called when loading script at first
	cfg.loadFile();
	ytd.checkYtdlpInfo();
}


string GetTitle()
{
	//called when loading script and closing config panel with ok button
	string scriptName = "yt-dlp " + SCRIPT_VERSION;
	if (cfg.critical_error != 0) ytd.error = 3;
	if (ytd.error > 0) scriptName += " " + ytd.errors[ytd.error];
	else if (cfg.stop == 1) scriptName += " (STOP)";
	else if (cfg.cookie_file.size() > 3) scriptName += " (cookie file)";
	else if (cfg.browser_name.size() > 3) scriptName += " (cookie " + cfg.browser_name + ")";
	return scriptName;
}


string GetConfigFile()
{
	//called when opening config panel
	cfg.isAlert = true;
	cfg.loadFile();
	return SCRIPT_CONFIG;
}


void ApplyConfigFile()
{
	//called when closing config panel with ok button
	cfg.loadFile();
}


string GetDesc()
{
	//called when opening info panel
	if (cfg.update_ytdlp == 2)
	{
		ytd.updateVersion();
		cfg.update_ytdlp = 0;
		cfg.setInt("Maintenance", "update_ytdlp", 0);
	}
	else
	{
		ytd.checkYtdlpInfo();
	}
	
	const string SITE_DEV = "https://github.com/yt-dlp/yt-dlp";
	//const string SITE_DESC = "https://";
	string info =
		"<a href=\"" + SITE_DEV + "\">yt-dlp development (github)</a>\r\n"
		//"<a href=\"" + SITE_DESC + "\">Description of this extention</a>\r\n"
		"\r\n";
	
	info += "yt-dlp.exe version: ";
	if (ytd.error > 0) info += "N/A " + ytd.errors[ytd.error];
	else info += ytd.version;
	
	switch (ytd.error)
	{
		case 1:
			info += "\r\n\r\n"
			"| Please place [yt-dlp.exe] in Module folder\r\n"
			"| under the PotPlayer's program folder.\r\n";
			break;
		case 2:
			info += "\r\n\r\n"
			"| Your [yt-dlp.exe] appears to be FAKE.\r\n"
			"| Please confirm in PotPlayer's Module folder\r\n"
			"| and replace with another one.\r\n";
			break;
		case 3:
			info += "\r\n\r\n"
			"| Your [yt-dlp.exe] doesn't work normally.\r\n"
			"| Remove it from PotPlayer's Module folder.\r\n"
			"| For using another one, reset [critical_error]\r\n"
			"| in config file.\r\n";
			break;
	}
	return info;
}


bool _IsYoutubeUrl(string url)
{
	url.MakeLower();
	
	if (HostRegExpParse(url, "^https?://(?:[-\\w.]+\\.)?youtube\\.com(?:[/?#].*)?$", {})) return true;
	
	if (HostRegExpParse(url, "^https?://(?:[-\\w.]+\\.)?youtu\\.be(?:[/?#].*)?$", {})) return true;
	
	return false;
}


string _GetUrlExtension(string url)
{
	url.MakeLower();
	array<dictionary> dicsMatch;
	if (HostRegExpParse(url, "^https?://[^\\?#]+/[^\\/?#]+\\.(\\w+)(?:[?#].+)?$", dicsMatch))
	{
		string ext;
		dicsMatch[1].get("first", ext);
		return ext;
	}
	return "";
}


bool _CheckExt(string ext, int kind)
{
	if (!ext.empty())
	{
		ext.MakeLower();
		array<string> exts;
		
		if (kind & 0x1 > 0)	//image
		{
			array<string> extsImage = {"jpg", "png", "gif", "webp"};
			exts.insertAt(exts.size(), extsImage);
		}
		if (kind & 0x10 > 0)	//video
		{
			array<string> extsVideo = {"avi", "wmv", "wmp", "wm", "asf", "mpg", "mpeg", "mpe", "m1v", "m2v", "mpv2", "mp2v", "ts", "tp", "tpr", "trp", "vob", "ifo", "ogm", "ogv", "mp4", "m4v", "m4p", "m4b", "3gp", "3gpp", "3g2", "3gp2", "mkv", "rm", "ram", "rmvb", "rpm", "flv", "swf", "mov", "qt", "amr", "nsv", "dpg", "m2ts", "m2t", "mts", "dvr-ms", "k3g", "skm", "evo", "nsr", "amv", "divx", "webm", "wtv", "f4v", "mxf"};
			exts.insertAt(exts.size(), extsVideo);
		}
		if (kind & 0x100 > 0)	//audio
		{
			array<string> extsAudio = {"wav", "wma", "mpa", "mp2", "m1a", "m2a", "mp3", "ogg", "m4a", "aac", "mka", "ra", "flac", "ape", "mpc", "mod", "ac3", "eac3", "dts", "dtshd", "wv", "tak", "cda", "dsf", "tta", "aiff", "aif", "aifc" "opus", "amr"};
			exts.insertAt(exts.size(), extsAudio);
		}
		if (kind & 0x1000 > 0)	//playlist
		{
			array<string> extsPlaylist = {"asx", "m3u", "m3u8", "pls", "wvx", "wax", "wmx", "cue", "mpls", "mpl", "dpl", "xspf", "mpd"};
				//exclude "xml", "rss"
			exts.insertAt(exts.size(), extsPlaylist);
		}
		if (kind & 0x10000 > 0)	//subtitles
		{
			array<string> extsSubtitles = {"smi", "srt", "idx", "sub", "sup", "psb", "ssa", "ass", "txt", "usf", "xss.*.ssf", "rt", "lrc", "sbv", "vtt", "ttml", "srv"};
			exts.insertAt(exts.size(), extsSubtitles);
		}
		if (kind & 0x100000 > 0)	//compressed
		{
			array<string> extsCompressed = {"zip", "rar", "tar", "7z", "gz", "xz", "cab", "bz2", "lzma", "rpm"};
			exts.insertAt(exts.size(), extsCompressed);
		}
		
		if (exts.find(ext) >= 0) return true;
	}
	
	return false;
}


bool PlayitemCheck(const string &in path)
{
	//called when an item is being opened after PlaylistCheck or PlaylistParse
	
	if (cfg.critical_error != 0) ytd.error = 3;
	if (ytd.error == 3 || cfg.stop == 1) return false;
	
	path.MakeLower();
	
	if (!HostRegExpParse(path, "^https?://", {})) return false;
	
	if (HostRegExpParse(path, "//192\\.168\\.\\d+\\.\\d+\\b", {})) return false;
		//Exclude LAN
	
	if (cfg.enable_youtube == 0 && _IsYoutubeUrl(path)) return false;
		//Exclude youtube according to the setting
	
	if (HostRegExpParse(path, "//(?:[-\\w.]+\\.)?kakao\\.com(?:[/?#].*)?$", {})) return false;
		//Exclude KakaoTV
	
	string ext = _GetUrlExtension(path);
	if (!ext.empty())	//hot-link to a web file
	{
		int kind = 0x0;
		if (cfg.hotlink_media_file < 1) kind |= 0x111;	//Exclude media files
		if (cfg.hotlink_playlist_file < 1) kind |= 0x1000;	//Exclude playlist files
		kind |= 0x110000;	//Exclude compressed/subtitles files
		if (_CheckExt(ext, kind)) return false;
	}
	
	return true;
}


string _OmitStr(string str, string search, int count = 1)
{
	if (count < 1) return str;
	int pos = 0;
	for (int i = 0; i < count; i++)
	{
		pos = str.find(search, pos);
		if (pos < 0) return str;
		pos += search.size();
	}
	pos -= search.size();
	return str.Left(pos);
}


string _FormatDate(string date)
{
	if (date.size() != 8) return date;
	string dateOut = HostRegExpParse(date, "(^\\d+)");
	if (dateOut.size() != 8) return date;
	dateOut = dateOut.substr(0, 4) + "-" + dateOut.substr(4, 2) + "-" + dateOut.substr(6, 2);
	return dateOut;
}


string _GetRadioThumbnail(bool isDirect)
{
	string fn = HostGetScriptFolder() + (isDirect ? RADIO_IMAGE_1 : RADIO_IMAGE_2);
	if (HostFileExist(fn)) return ("file://" + fn);
	return "";
}


string _JudgeDomain(string domain)
{
	if (domain.empty()) return "";
	int pos = domain.findLast(":");
	if (pos > 0) domain = domain.Left(pos);	//remove port number
	if (domain.find(":") < 0)	//exclude IP address of IPv6
	{
		if (!HostRegExpParse(domain, "^[\\d.]+$", {}))	//exclude ip address of IPv4
		{
			if (domain.Left(3) != "cdn")
			{
				return domain;
			}
		}
	}
	return "";
}


bool _SelectAutoSub(string code, array<dictionary> dicsSub)
{
	if (code.empty()) return false;
	
	string lang;
	
	int pos = code.find("-orig");
	if (pos > 0) {
		//original language of contents
		lang = code.Left(pos);
	}
	else if (HostRegExpParse(code, "^" + cfg.baseLang + "\\b", {}))
	{
		//user's base language
		//If baseLang is "pt", both "pt-BR" and "pt-PT" are considered to be match.
		lang = code;
	}
	
	if (lang.empty()) return false;
	
	for (uint i = 0; i <dicsSub.size(); i++)
	{
		string code1;
		if (dicsSub[i].get("langCode", code1))
		{
			if (lang == code1) return false;	//duplicated
		}
	}
	
	return true;
}


bool __IsSameQuality(dictionary dic1, dictionary dic0)
{
	array<string> keys = {
		"quality",
		"format",
		"fps",
		"dynamicRange",
		"language",
		//"is360",
		//"type3D"
	};
	
	for (uint j = 0; j < keys.size(); j++)
	{
		if (keys[j].empty()) break;
		
		if (!dic0.exists(keys[j]))
		{
			if (dic1.exists(keys[j])) return false;
		}
		else
		{
			if (!dic1.exists(keys[j])) return false;
			string strVal0 = string(dic0[keys[j]]);
			if (!strVal0.empty())
			{
				string strVal1 = string(dic1[keys[j]]);
				if (strVal1.empty()) return false;
				if (strVal1 != strVal0)
				{
					if (keys[j] != "quality") return false;
					
					//If the difference of bitrate is small, two audio quolities are considered the same.
					if (strVal0.Right(1) != "K" || strVal1.Right(1) != "K") return false;
					float fltVal0 = parseFloat(strVal0);
					float fltVal1 = parseFloat(strVal1);
					float d = fltVal0 - fltVal1;
					if (d < 0) d *= -1;
					if (d > 10) return false;
				}
			}
			else
			{
				float fltVal0 = float(dic0[keys[j]]);
				float fltVal1 = float(dic1[keys[j]]);
				if (fltVal1 != fltVal0) return false;
			}
		}
	}
	return true;
}


bool _IsSameQuality(dictionary dic, array<dictionary> dics)
{
	for (int i =dics.size() - 1; i >= 0; i--)
	{
		dictionary dic0 =dics[i];
		if (__IsSameQuality(dic, dic0)) return true;
	}
	return false;
}


string _GetJsonValueString(JsonValue json, string key)
{
	string str = "";
	if (!key.empty())
	{
		JsonValue j_value = json[key];
		if (j_value.isString()) str = j_value.asString();
	}
	return str;
}


float _GetJsonValueFloat(JsonValue json, string key)
{
	float f = -10000;
	if (!key.empty())
	{
		JsonValue j_value = json[key];
		if (j_value.isFloat()) f = j_value.asFloat();
	}
	return f;
}


int _GetJsonValueInt(JsonValue json, string key)
{
	int i = -10000;
	if (!key.empty())
	{
		JsonValue j_value = json[key];
		if (j_value.isInt()) i = j_value.asInt();
	}
	return i;
}


bool _GetJsonValueBool(JsonValue json, string key)
{
	bool b = false;
	if (!key.empty())
	{
		JsonValue j_value = json[key];
		if (j_value.isBool()) b = j_value.asBool();
	}
	return b;
}


string PlayitemParse(const string &in path, dictionary &MetaData, array<dictionary> &QualityList)
{
	//called after PlayitemCheck if it returns true
	
	array<string> entries = ytd.exec(path, false);
	if (entries.size() == 0) return "";
	
	string json = entries[0];
	JsonReader reader;
	JsonValue root;
	if (!reader.parse(json, root) || !root.isObject())
	{
		if (cfg.console_out > 0) HostPrintUTF8("[yt-dlp] ERROR! Json data corrupted.\r\n");
		return "";
	}
	JsonValue j_version = root["_version"];
	if (!j_version.isObject()) {ytd.criticalError(); return "";}
	else
	{
		string version = _GetJsonValueString(j_version, "version");
		if (version.empty()) {ytd.criticalError(); return "";}
		else
		{
			if (version != ytd.version)
			{
				if (cfg.update_ytdlp == 1)
				{
					string msg = "[yt-dlp.exe] is up to date.\r\nversion: " + version;
					HostMessageBox(msg, "[yt-dlp]", 2, 0);
					ytd.error = -1;
					ytd.checkYtdlpInfo();
				}
				else
				{
					ytd.criticalError(); return "";
				}
			}
		}
	}
	string extractor = _GetJsonValueString(root, "extractor_key");
	if (extractor.empty()) extractor = _GetJsonValueString(root, "extractor");
	if (extractor.empty())
	{
		if (cfg.console_out > 0) HostPrintUTF8("[yt-dlp] ERROR! No extractor.\r\n");
		return "";
	}
	string webUrl = _GetJsonValueString(root, "webpage_url");
	if (webUrl.empty())
	{
		if (cfg.console_out > 0) HostPrintUTF8("[yt-dlp] ERROR! No webpage url.\r\n");
		return "";
	}
	
	int playlistIdx = _GetJsonValueInt(root, "playlist_index");
	if (playlistIdx > 0 && path != webUrl)
	{
		//Exclude playlist url
		if (cfg.console_out > 0) HostPrintUTF8("[yt-dlp] ERROR! This url is for playlist. You need to fetch url of each entry in it. - \"" + path +"\"\r\n");
		return "";
	}
	bool isLive = _GetJsonValueBool(root, "is_live");
	if (isLive && cfg.no_youtube_live == 1 && _IsYoutubeUrl(path))
	{
		if (cfg.console_out > 0) HostPrintUTF8("[yt-dlp] YouTube live is passed through by \"no_youtube_live\". - \"" + path +"\"\r\n");
		return "";
	}
	
	string urlOut = _GetJsonValueString(root, "url");
	MetaData["webUrl"] = webUrl;
	
	string id = _GetJsonValueString(root, "id");
	if (!id.empty()) MetaData["vid"] = id;
	
	string baseName = _GetJsonValueString(root, "webpage_url_basename");
	string ext2 = HostGetExtension(baseName);	//include the top dot
	
	string title = _GetJsonValueString(root, "title");
	string title2;	//substantial title
	if (!title.empty())
	{
		if (!baseName.empty())
		{
			if (baseName == title + ext2)
			{
				//MetaData["title"] is empty if yt-dlp cannot get a substantial title.
				//Prevent potplayer from changing title in playlist.
			}
			else
			{
				title2 = title;
				MetaData["title"] = title2;
			}
		}
	}
	
	string ext = _GetJsonValueString(root, "ext");
	if (!ext.empty()) MetaData["fileExt"] = ext;
	
	bool isAudioExt = _CheckExt(ext, 0x100);
	bool isDirect = _GetJsonValueBool(root, "direct");
	
	string thumbnail = _GetJsonValueString(root, "thumbnail");
	if (thumbnail.empty())
	{
		if (isAudioExt && cfg.radio_thumbnail == 1)
		{
			thumbnail = _GetRadioThumbnail(isDirect);
			if (!thumbnail.empty()) MetaData["thumbnail"] = thumbnail;
		}
		else
		{
			thumbnail = webUrl;
		}
	}
	if (!thumbnail.empty()) MetaData["thumbnail"] = thumbnail;
	
	string author = _GetJsonValueString(root, "channel");
	if (author.empty())
	{
		author = _GetJsonValueString(root, "uploader");
		if (author.empty())
		{
			author = _GetJsonValueString(root, "atrist");
			if (author.empty())
			{
				author = _GetJsonValueString(root, "creator");
				if (author.empty())
				{
					if (isAudioExt)
					{
						//online radio with changing title dynamically
						if (!title2.empty()) author = title2;
					}
					else
					{
						if (extractor != "Generic" && extractor != "generic")
						{
							if (extractor != "HTML5MediaEmbed" && extractor != "html5")
							{
								author = extractor;
							}
						}
					}
					if (author.empty())
					{
						string urlDomain = _GetJsonValueString(root, "webpage_url_domain");
						author = _JudgeDomain(urlDomain);
						if (author.empty())
						{
							if (isAudioExt) author = title;
							else author = extractor;
						}
					}
				}
			}
		}
	}
	MetaData["author"] = author;
	
	string date = _GetJsonValueString(root, "upload_date");
	date = _FormatDate(date);
	if (!date.empty()) MetaData["date"] = date;
	
	string description = _GetJsonValueString(root, "description");
	if (!description.empty()) MetaData["content"] = description;
	
	int viewCount = _GetJsonValueInt(root, "view_count");
	if (viewCount > 0) MetaData["viewCount"] = formatInt(viewCount);
	
	int likeCount = _GetJsonValueInt(root, "like_count");
	if (likeCount > 0) MetaData["likeCount"] = formatInt(likeCount);
	
	JsonValue j_formats = root["formats"];
	if (!j_formats.isArray() || j_formats.size() == 0)
	{
		//Don't treat it as an error.
		//For getting uploader(website) or thumbnail or upload date.
		if (cfg.console_out > 0) HostPrintUTF8("[yt-dlp] No \"formats\" data...\r\n");
	}
	
	uint vaCount = 0;
	uint vCount = 0;
	uint aCount = 0;
	for (int i = j_formats.size() - 1; i >= 0 ; i--)
	{
		JsonValue j_format = j_formats[i];
		
		string protocol = _GetJsonValueString(j_format, "protocol");
		if (protocol.empty()) continue;
		if (protocol != "http" && protocol != "https" && protocol.Left(4) != "m3u8") continue;
		
		int qualityIdx = _GetJsonValueInt(j_format, "quality");
		
		string fmtUrl = _GetJsonValueString(j_format, "url");
		if (fmtUrl.empty()) continue;
		if (urlOut.empty()) urlOut = fmtUrl;
		
		if (@QualityList !is null)
		{
			string fmtExt = _GetJsonValueString(j_format, "ext");
			string vExt = _GetJsonValueString(j_format, "video_ext");
			string aExt = _GetJsonValueString(j_format, "audio_ext");
			if (fmtExt.empty() || vExt.empty() || aExt.empty()) continue;
			
			string vcodec = _GetJsonValueString(j_format, "vcodec");
			vcodec = _OmitStr(vcodec, ".", 1);
			
			string acodec = _GetJsonValueString(j_format, "acodec");
			acodec = _OmitStr(acodec, ".", 1);
			
			string va;
			if (vExt != "none" || vcodec != "none")
			{
				if (aExt != "none" || acodec != "none")
				{
					va = "va";	//video with audio
				}
				else
				{
					va = "v";	//video only
				}
			}
			else
			{
				if (qualityIdx == -1) continue;	//audio for non-merged in youtube
				if (aExt != "none" || acodec != "none")
				{
					va = "a";	//audio only
				}
				else
				{
					continue;
				}
			}
			
			int width = _GetJsonValueInt(j_format, "width");
			if (width > 0 && cfg.reduce_low_quality == 1)
			{
				if (va == "v")
				{
					if (width < 360 && vCount >= 3) continue;
					if (width < 480 && vCount >= 6) continue;
				}
				else if (va == "va")
				{
					if (width < 360 && vaCount >= 3) continue;
					if (width < 480 && vaCount >= 6) continue;
				}
			}
			
			int height = _GetJsonValueInt(j_format, "height");
			if (height > 0 && cfg.reduce_low_quality == 1)
			{
				if (va == "v")
				{
					if (height < 360 && vCount >= 3) continue;
					if (height < 480 && vCount >= 6) continue;
				}
				else if (va == "va")
				{
					if (height < 360 && vaCount >= 3) continue;
					if (height < 480 && vaCount >= 6) continue;
				}
			}
			
			float abr = _GetJsonValueFloat(j_format, "abr");
			if (abr > 0 && cfg.reduce_low_quality == 1)
			{
				if (va == "a")
				{
					if (abr < 100 && aCount >= 2) continue;
				}
			}
			
			float vbr = _GetJsonValueFloat(j_format, "vbr");
			float tbr = _GetJsonValueFloat(j_format, "tbr");
			
			string bitrate;
			if (tbr > 0) bitrate = HostFormatBitrate(int(tbr * 1000));
			else if (vbr > 0 && abr > 0) bitrate = HostFormatBitrate(int((abr + vbr) * 1000));
			else if (vbr > 0) bitrate = HostFormatBitrate(int(vbr * 1000));
			else if (abr > 0) bitrate = HostFormatBitrate(int(abr * 1000));
			
			float fps = _GetJsonValueFloat(j_format, "fps");
			
			string dynamicRange = _GetJsonValueString(j_format, "dynamic_range");
			if (dynamicRange.empty() && va != "a") dynamicRange = "SDR";
			
			int itag = _GetJsonValueInt(j_format, "format_id");
			
			string resolution = "";
			if (width > 0 && height > 0)
			{
				resolution = formatInt(width) + "×" + formatInt(height);
			}
			
			string quality;
			string format;
			string language;
			string note;
			
			if (va == "a")
			{
				float bps = tbr > 0 ? tbr : abr;
				if (bps <= 0) bps = 128;
				quality = HostFormatBitrate(int(bps * 1000));
				
				language = _GetJsonValueString(j_format, "language");
				if (!language.empty())
				{
					note = _GetJsonValueString(j_format, "format_note");
					if (!note.empty())
					{
						note = _OmitStr(note, ",");
						array<string> _qualities = {
							"low", "medium", "high", "Default"
						};
						if (_qualities.find(note) < 0)
						{
							//show only language name
							format += note + ", ";
						}
					}
				}
				format += fmtExt;
				if (!acodec.empty() && acodec != "none")
				{
					format += ", " + acodec;
				}
				
				if (itag <= 0 || HostExistITag(itag))
				{
					itag = HostGetITag(0, int(bps), fmtExt == "mp4", fmtExt == "webm" || fmtExt == "m3u8");
					if (itag < 0) itag = HostGetITag(0, int(bps), true, true);
				}
			}
			else if (va == "v")
			{
				if (!resolution.empty()) quality = resolution;
				
				format += fmtExt;
				if (!vcodec.empty() && vcodec != "none")
				{
					format += ", " + vcodec;
				}
				
				if (itag <= 0 || HostExistITag(itag))
				{
					itag = HostGetITag(height, 0, fmtExt == "mp4", fmtExt == "webm" || fmtExt == "m3u8");
					if (itag < 0) itag = HostGetITag(height, 0, true, true);
				}
			}
			else if (va == "va")
			{
				if (!resolution.empty()) quality = resolution;
				
				format += fmtExt;
				if (!vcodec.empty() && vcodec != "none")
				{
					if (!acodec.empty() && acodec != "none")
					{
						format += ", " + vcodec + "/" + acodec;
					}
				}
				
				if (itag <= 0 || HostExistITag(itag))
				{
					if (height > 0 && abr < 1) abr = 1;
					itag = HostGetITag(height, int(abr), fmtExt == "mp4", fmtExt == "webm" || fmtExt == "m3u8");
					if (itag < 0) itag = HostGetITag(height, int(abr), true, true);
				}
			}
			if (quality.empty())
			{
				quality = _GetJsonValueString(j_format, "format_id");
				if (quality.empty())
				{
					quality = _GetJsonValueString(j_format, "format");
					quality = _OmitStr(quality, " ");
				}
			}
			
			dictionary dic;
			dic["url"] = fmtUrl;
			dic["resolution"] = resolution;
			if (!bitrate.empty()) dic["bitrate"] = bitrate;
			if (!quality.empty()) dic["quality"] = quality;
			dic["format"] = format;
				//if (!vcodec.empty()) dic["vcodec"] = vcodec;
				//if (!acodec.empty()) dic["acodec"] = acodec;
			if (fps > 0) dic["fps"] = fps;
			if (!language.empty()) dic["language"] = language;
			if (!dynamicRange.empty())
			{
				dic["dynamicRange"] = dynamicRange;
				if (dynamicRange.find("SDR") < 0) dic["isHDR"] = true;
			}
			
//HostPrintUTF8("itag: " + itag + "\tquality: " + quality + "\tformat: " + format + "\tfps: " + fps);
			
			while (HostExistITag(itag)) itag++;
			HostSetITag(itag);
			dic["itag"] = itag;
			
			if (cfg.remove_duplicated_quality == 1)
			{
				if (_IsSameQuality(dic, QualityList)) continue;
			}
			
			if (va == "v") vCount++;
			else if (va == "a") aCount++;
			else if (va == "va") vaCount++;
			
			QualityList.insertLast(dic);
		}
	}
	
	if (@QualityList !is null)
	{
		array<dictionary> dicsSub;
		JsonValue j_subtitles = root["requested_subtitles"];
		if (j_subtitles.isObject())
		{
			array<string> subs = j_subtitles.getKeys();
			for (uint i = 0; i < subs.size(); i++)
			{
				string langCode = subs[i];
				JsonValue j_sub = j_subtitles[langCode];
				if (j_sub.isObject())
				{
					string subUrl = _GetJsonValueString(j_sub, "url");
					if (!subUrl.empty())
					{
						dictionary dic;
						dic["langCode"] = langCode;
						dic["url"] = subUrl;
						string subName = _GetJsonValueString(j_sub, "name");
						if (!subName.empty()) dic["name"] = subName;
						
						if (HostRegExpParse(langCode, "\\b[Aa]uto", {}))
						{
							//Auto-generated
							dic["kind"] = "asr";
						}
						
						dicsSub.insertLast(dic);
					}
				}
			}
		}
		j_subtitles = root["automatic_captions"];
		if (j_subtitles.isObject())
		{
			array<string> subs = j_subtitles.getKeys();
			for (uint i = 0; i < subs.size(); i++)
			{
				string langCode = subs[i];
				if (_SelectAutoSub(langCode, dicsSub))
				{
					JsonValue j_subs = j_subtitles[langCode];
					if (j_subs.isArray())
					{
						for (int j = j_subs.size() - 1; j >= 0; j--)
						{
							JsonValue j_ssub = j_subs[j];
							if (j_ssub.isObject())
							{
								string subExt = _GetJsonValueString(j_ssub, "ext");
								if (!subExt.empty())
								{
									if (subExt.find("vtt") >= 0 || subExt.find("srv") >= 0)
									{
										string subUrl = _GetJsonValueString(j_ssub, "url");
										if (!subUrl.empty())
										{
											dictionary dic;
											dic["kind"] = "asr";
											dic["langCode"] = langCode;
											dic["url"] = subUrl;
											string subName = _GetJsonValueString(j_ssub, "name");
											if (!subName.empty())
											{
												if (subName.replace("(Original)", "(auto-generated)") == 0)
												{
													subName += " (auto-generated)";
												}
												dic["name"] = subName;
											}
											dicsSub.insertLast(dic);
											break;
										}
									}
								}
							}
						}
					}
				}
			}
		}
		if (dicsSub.size() > 0) MetaData["subtitle"] = dicsSub;
		
		array<dictionary> dicsChapter;
		JsonValue j_chapters = root["chapters"];
		if (j_chapters.isArray())
		{
			for(int i = 0; i < j_chapters.size(); i++)
			{
				JsonValue j_chapter = j_chapters[i];
				if (j_chapter.isObject())
				{
					string cptTitle = _GetJsonValueString(j_chapter, "title");
					if (!cptTitle.empty())
					{
						float cTime = _GetJsonValueFloat(j_chapter, "start_time");
						if (cTime >= 0)
						{
							dictionary dic;
							dic["title"] = cptTitle;
							dic["time"] = formatInt(int(cTime * 1000));	//milli-second
							dicsChapter.insertLast(dic);
						}
					}
				}
			}
		}
		if (dicsChapter.size() > 0) MetaData["chapter"] = dicsChapter;
	}
	
	if (cfg.console_out > 0) HostPrintUTF8("[yt-dlp] Parsing completed by " + extractor + ". - \"" + path +"\"\r\n");
	return urlOut;
}


bool PlaylistCheck(const string &in path)
{
	//called when a new item is being opend from a location other than potplayer's playlist
	//Some playlist extraction may freeze yt-dlp.
	
	if (!PlayitemCheck(path)) return false;
	
	if (_IsYoutubeUrl(path))
	{
		if (cfg.enable_youtube < 2) return false;
	}
	else
	{
		if (cfg.website_playlist < 1) return false;
	}
	
	string ext = _GetUrlExtension(path);
	if (!ext.empty())
	{
		if (_CheckExt(ext, 0x110111)) return false;
		if (_CheckExt(ext, 0x1000))
		{
			if (cfg.hotlink_playlist_file < 2) return false;
		}
	}
	
	return true;
}


dictionary _PlaylistParse(string json)
{
	dictionary dic;
	
	if (!json.empty())
	{
		JsonReader reader;
		JsonValue root;
		if (reader.parse(json, root) && root.isObject())
		{
			string extractor = _GetJsonValueString(root, "extractor_key");
			if (extractor.empty()) extractor = _GetJsonValueString(root, "extractor");
			if (!extractor.empty()) dic["extractor"] = extractor;
			
			int playlistIdx = _GetJsonValueInt(root, "playlist_index");
			if (playlistIdx >= 0) dic["playlistIdx"] = playlistIdx;
			
			string url = _GetJsonValueString(root, "original_url");
			if (url.empty()) url = _GetJsonValueString(root, "webpage_url");
			if (!url.empty())
			{
				int pos = url.find("#__youtubedl");
				if (pos > 0) url = url.Left(pos);
					//remove parameter added by yt-dlp
				dic["url"] = url;
			}
			
			string title = _GetJsonValueString(root, "title");
			if (!title.empty())
			{
				string baseName = _GetJsonValueString(root, "webpage_url_basename");
				if (!baseName.empty())
				{
					string ext2 = HostGetExtension(baseName);
					if (baseName == title + ext2)
					{
						//dic["title"] is empty if yt-dlp cannot get a substantial title.
						//Prevent potplayer from changing title in playlist.
					}
					else
					{
						dic["title"] = title;
					}
				}
			}
			
			string ext = _GetJsonValueString(root, "ext");
			bool isAudioExt = _CheckExt(ext, 0x100);
			bool isDirect = _GetJsonValueBool(root, "direct");
			
			string thumbnail = _GetJsonValueString(root, "thumbnail");
			if (thumbnail.empty())
			{
				JsonValue j_thumbs = root["thumbnails"];
				if (j_thumbs.isArray())
				{
					int n = j_thumbs.size();
					if (n > 0)
					{
						JsonValue j_thumbmax = j_thumbs[n - 1];
						if (j_thumbmax.isObject())
						{
							thumbnail = _GetJsonValueString(j_thumbmax, "url");
						}
					}
				}
			}
			if (thumbnail.empty())
			{
				if (isAudioExt && cfg.radio_thumbnail == 1)
				{
					thumbnail = _GetRadioThumbnail(isDirect);
				}
				else
				{
					if (!url.empty()) thumbnail = url;
				}
			}
			if (!thumbnail.empty()) dic["thumbnail"] = thumbnail;
			
			string duration = _GetJsonValueString(root, "duration_string");
			if (duration.empty())
			{
				int durationSec = _GetJsonValueInt(root, "duration");
				if (durationSec > 0) duration = "0:" + durationSec;
					//Convert to format "hh:mm:ss" by adding "0:" to the top.
			}
			if (!duration.empty()) dic["duration"] = duration;
		}
	}
	
	return dic;
}


array<dictionary> PlaylistParse(const string &in path)
{
	//called after PlaylistCheck if it returns true
	
	array<string> entries = ytd.exec(path, true);
	if (entries.size() == 0) return {};
	
	array<dictionary> dicsEntry;
	int count = 0;
	for (uint i = 0; i < entries.size(); i++)
	{
		dictionary dic = _PlaylistParse(entries[i]);
		string urlEntry;
		if (dic.get("url", urlEntry) && !urlEntry.empty())
		{
			int index = int(dic["playlistIdx"]);
			if (index > 0)
			{
				if (cfg.console_out > 0)
				{
					if (count == 0)
					{
						string extractor;
						if (dic.get("extractor", extractor) && !extractor.empty())
						{
							HostPrintUTF8("Extractor: " + extractor);
						}
					}
					HostPrintUTF8("Url " + index + ": " + urlEntry);
				}
				dicsEntry.insertLast(dic);
				count++;
			}
		}
	}
	
	if (cfg.console_out > 0) HostPrintUTF8("[yt-dlp] Playlist entries: " + count + "    - \"" + path +"\"\r\n");
	return dicsEntry;
}


