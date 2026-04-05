/*************************************************************
  Parse Streaming with yt-dlp
**************************************************************
  Extension script for PotPlayer 260114 or later versions
  Placed in \PotPlayer\Extension\Media\PlayParse\
*************************************************************/

string SCRIPT_VERSION = "260405";


string YTDLP_EXE = "yt-dlp.exe";
	// yt-dlp executable file. Placed in "ytdlp_location". (required)

string SCRIPT_CONFIG_DEFAULT = "yt-dlp_default.ini";
	// Default configuration file. Placed in HostGetScriptFolder(). (required)

string SCRIPT_CONFIG_CUSTOM = "Extension\\Media\\PlayParse\\yt-dlp.ini";
	// Configuration file. Relative path to HostGetConfigFolder().
	// Created automatically with this script.

string RADIO_IMAGE_1 = "yt-dlp_radio1.jpg";
string RADIO_IMAGE_2 = "yt-dlp_radio2.jpg";
string PLAYLIST_IMAGE = "yt-dlp_playlist.jpg";
	// Radio/playlist image files. Placed in HostGetScriptFolder().



// Threshold time (milliseconds)
uint DOUBLE_TRIGGER_INTERVAL_1 = 1200;
uint DOUBLE_TRIGGER_INTERVAL_2 = 3000;



class FILE_CONFIG
{
	string codeDef;	// encoding of default config file
	
	bool showDialog = false;
	bool defCfgError = false;
	bool cstCfgError = false;
	
	string BOM_UTF8 = "\xEF\xBB\xBF";
	string BOM_UTF16LE = "\xFF\xFE";
	//string BOM_UTF16BE = "\xFE\xFF";
	
	string _changeEolWin(string str)
	{
		// LF -> CRLF
		// Not available if EOL is only CR
		int pos = 0;
		int pos0;
		do {
			pos0 = pos;
			pos = str.find("\n", pos);
			if (pos >= 0)
			{
				if (pos == 0 || str.substr(pos - 1, 1) != "\r")
				{
					str.insert(pos, "\r");
					pos += 2;
				}
				else
				{
					pos += 1;
				}
			}
		} while (pos > pos0);
		return str;
	}
	
	string _changeToUtf8Basic(string str, string &out code)
	{
		// Change to utf8 without top BOM
		if (str.find(BOM_UTF8) == 0)
		{
			code = "utf8_bom";
			str = str.substr(BOM_UTF8.length());
		}
		else if (str.find(BOM_UTF16LE) == 0)
		{
			code = "utf16_le";
			str = str.substr(BOM_UTF16LE.length());
			str = HostUTF16ToUTF8(str);
		}
		else
		{
			// Consider codes only as utf8 or utf16le
			code = "utf8_raw";
		}
		str = _changeEolWin(str);
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
		else
		{
			//code = "utf8_raw";
			// consider codes only as utf8 or utf16le
		}
		return str;
	}
	
	string readFileDef()
	{
		string str;
		string msg = "";
		string path = HostGetScriptFolder() + SCRIPT_CONFIG_DEFAULT;
		uintptr fp = HostFileOpen(path);
		if (fp == 0)
		{
			msg =
			"Default config file not found.\r\n"
			"Please place it in the same folder as the script.\r\n\r\n";
			codeDef = "";
		}
		else
		{
			str = HostFileRead(fp, HostFileLength(fp));
			HostFileClose(fp);
			
			if (str.empty())
			{
				msg =
				"Default config file empty.\r\n"
				"Please use a valid config file.\r\n\r\n";
			}
			else if (str.find("\n") < 0)
			{
				msg =
				"Default config file not available.\r\n"
				"Please use a valid config file.\r\n"
				"(Supported line endings: CRLF or LF)\r\n\r\n";
			}
			else
			{
				str = _changeToUtf8Basic(str, codeDef);
				if (!HostRegExpParse(str, "(?:^|\\n)\\w+=", {}))
				{
					msg =
					"Cannot read default config file.\r\n"
					"Please use a valid config file.\r\n"
					"(Supported encodings: UTF8(BOM) or UTF16 LE)\r\n\r\n";
					codeDef = "";
				}
				else
				{
					if (SCRIPT_VERSION.Right(1) != "#")
					{
						string curVer = SCRIPT_VERSION.Left(6);
						int pos = str.find("VERSION " + curVer);
						if (pos < 0 || pos > 10)
						{
							msg =
							"This default config file is for a different version of the script.\r\n"
							"Try clicking the [Reload files] button.\r\n\r\n"
							"If the problem continues, check the versions of both the script and the following file.\r\n\r\n";
						}
					}
				}
			}
		}
		
		if (msg.empty())
		{
			defCfgError = false;
		}
		else
		{
			defCfgError = true;
			str = "";
			if (showDialog)
			{
				showDialog = false;
				msg += HostGetScriptFolder() + "\r\n" + SCRIPT_CONFIG_DEFAULT;
				HostMessageBox(msg, "[yt-dlp] ERROR: Default Config File", 0, 0);
			}
		}
		return str;
	}
	
	bool _createFolder(string folder)
	{
		// This folder is relative to HostGetConfigFolder().
		// It does not include a file name.
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
		// This path is relative to HostGetConfigFolder().
		// It includes a file name.
		string folder = path;
		int pos = folder.findLast("\\");
		folder = (pos >= 0) ? folder.Left(pos) : "";
		if (_createFolder(folder))
		{
			return HostFileCreate(path);
		}
		return 0;
	}
	
	uintptr openFileCst(string &out str)
	{
		str = "";
		uintptr fp = _createFolderFile(SCRIPT_CONFIG_CUSTOM);
		if (fp > 0)
		{
			str = HostFileRead(fp, HostFileLength(fp));
			string code;
			str = _changeToUtf8Basic(str, code);
			if (str.findFirstNotOf("\r\n") < 0) str = "";
		}
		return fp;
	}
	
	int closeFileCst(uintptr fp, bool write, string str)
	{
		int writeState = 0;
		if (fp > 0)
		{
			if (write)
			{
				str = _changeFromUtf8Basic(str, codeDef);
				if (HostFileSetLength(fp, 0) == 0)
				{
					if (HostFileWrite(fp, str) == int(str.length()))
					{
						writeState = 2;
					}
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
		
		if (writeState > 0)
		{
			cstCfgError = false;
		}
		else
		{
			cstCfgError = true;
			if (showDialog)
			{
				showDialog = false;
				string msg =
				"The script cannot create or save the config file.\r\n"
				"Please make sure this file is writable.\r\n\r\n"
				+ HostGetConfigFolder() + SCRIPT_CONFIG_CUSTOM;
				HostMessageBox(msg, "[yt-dlp] ERROR: File Save", 0, 0);
			}
		}
		return writeState;
	}
	
}

FILE_CONFIG fc;

//----------------------- END of class FILE_CONFIG -------------------------


class KeyData
{
	string section;
	string key;
	string areaStr;
	string value;
	int state = -1;
	int keyTop = -1;
	int valueTop = -1;
	int areaTop = -1;
	
	KeyData(string _section, string _key)
	{
		section = _section;
		key = _key;
	}
	
	KeyData()
	{
	}
	
	void init()
	{
		areaStr = "";
		value = "";
		state = -1;
		keyTop = -1;
		valueTop = -1;
		areaTop = -1;
	}
}

//----------------------- END of class KeyData -------------------------


class CFG
{
	array<string> sectionNamesDef;	// default section names
	array<string> sectionNamesCst;	// customize section order
	dictionary keyNames;	// {section, {key}} dictionary with array
	
	dictionary kdsDef;	// default data
	dictionary kdsCst;	// customized data
		// {section, {key, KeyData}} dictionary with dictionary
	
	// specific properties of each script
	int csl = 0;	// console out
	string baseLang;
	array<string> autoSubLangs = {};
	
	int _findBlankLine(string str, int pos)
	{
		if (pos < 0) pos = str.length();
		pos = str.findLastNotOf("\r\n", pos);
		if (pos < 0) pos = 0;
		int pos0;
		do {
			pos0 = pos;
			pos = str.find("\n", pos);
			if (pos >= 0)
			{
				for (pos += 1; uint(pos) < str.length(); pos++)
				{
					string c = str.substr(pos, 1);
					if (c == "\n") return pos + 1;
					if (c != "\r") break;
				}
			}
		} while (pos > pos0);
		return str.length();
	}
	
	string _removeLastBlank(string str)
	{
		int pos = str.findLastNotOf("\r\n");
		if (pos >= 0) pos += 1;
		else pos = 0;
		str = str.Left(pos);
		str += "\r\n";
		return str;
	}
	
	int _findSectionSepaNext(string str, int from)
	{
		int pos = str.find("\n[", from);
		if (pos >= 0) pos += 1; else pos = _findBlankLine(str, -1);
		return pos;
	}
	
	string _getSectionNext(string str, int &inout pos)
	{
		if (str.empty() || pos < 0 || uint(pos) >= str.length()) {pos = -1; return "";}
		
		string section = "";
		pos = tx.findRegExp(str, "(?:^|\\n)\\[([^\n\r\t\\]]*?)\\]", section, pos);
		if (pos > 0) pos -= 1;
		return section;
	}
	
	string _getSectionAreaNext(string str, string &out section, int &inout pos)
	{
		string sectArea;
		section = _getSectionNext(str, pos);
		if (pos >= 0)
		{
			int pos2 = _findSectionSepaNext(str, pos);
			sectArea = str.substr(pos, pos2 - pos);
		}
		return sectArea;
	}
	
	string _getKeyNext(string str, int &inout pos)
	{
		if (str.empty() || pos < 0 || uint(pos) >= str.length()) {pos = -1; return "";}
		string key;
		pos = tx.findRegExp(str, "(?:^|\\n)(#?\\w+)=", key, pos);
		if (pos >= 0 && pos <= _findSectionSepaNext(str, pos))
		{
			return key;
		}
		return "";
	}
	
	string _getKeyAreaNext(string str, string &out key, int &inout pos)
	{
		string keyArea;
		key = _getKeyNext(str, pos);
		if (pos >= 0)
		{
			int pos2 = _findBlankLine(str, pos);
			int sepa = _findSectionSepaNext(str, pos);
			if (pos2 > sepa) pos2 = sepa;
			keyArea = str.substr(pos, pos2 - pos);
		}
		return keyArea;
	}
	
	int _findKeyTop(string sectArea, string key)
	{
		int pos = tx.findRegExp(sectArea, "(?:^|\\n)([^\t\r\n]*\\b" + key + ") *=");
		return pos;
	}
	
	string _removeTabLine(string keyArea)
	{
		int pos1;
		int pos2 = 0;
		while (pos2 >= 0)
		{
			pos1 = pos2;
			string line;
			pos2 = tx.findRegExp(keyArea, "(?:^|\\n)(\t[^\r\n]*\r\n)", line, pos1);
			if (pos2 >= 0)
			{
				keyArea.erase(pos2, line.length());
			}
		}
		return keyArea;
	}
	
	int _findDescriptionTop(string keyAreaDef)
	{
		int pos = keyAreaDef.find("\r\n\t");
		if (pos > 0) pos += 2;
		return pos;
	}
	
	void _parseKeyDataDef(KeyData &inout kd)
	{
		if (kd.key.empty()) {kd.init(); return;}
		if (kd.areaStr.empty()) {kd.init(); return;}
		
		kd.value = HostRegExpParse(kd.areaStr, "(?:^|\\n)" + kd.key + "=(\\S[^\t\r\n]*)");
	}
	
	void __loadDef(string str, string section, int pos)
	{
		array<string> keys = {};
		dictionary _kds;
		int sepa = _findSectionSepaNext(str, pos);
		int pos0;
		do {
			pos0 = pos;
			string key;
			string keyArea = _getKeyAreaNext(str, key, pos);
			if (pos >= 0 && pos < sepa)
			{
				keys.insertLast(key);
				KeyData kd(section, key);
				kd.areaStr = keyArea;
				_parseKeyDataDef(kd);
				_kds.set(key, kd);
				pos += keyArea.length();
			}
			else
			{
				break;
			}
		} while (pos > pos0);
		keyNames.set(section, keys);
		kdsDef.set(section, _kds);
	}
	
	bool _loadDef()
	{
		string str = fc.readFileDef();
		if (str.empty()) return false;
		
		kdsDef = {};
		sectionNamesDef = {};
		keyNames = {};
		int pos = 0;
		int pos0;
		do {
			pos0 = pos;
			string section;
			string sectArea = _getSectionAreaNext(str, section, pos);
			if (pos >= 0)
			{
				if (!section.empty())
				{
					sectionNamesDef.insertLast(section);
					__loadDef(str, section, pos);
				}
				pos += sectArea.length();
			}
			else
			{
				break;
			}
		} while (pos > pos0);
		
		if (sectionNamesDef.length() == 0)
		{
			sectionNamesDef.insertLast("");
			__loadDef(str, "", 0);
		}
		
		return true;
	}
	
	void _keyCommentOut(KeyData &inout kd)
	{
		string str = kd.areaStr;
		int pos = 0;
		int pos0;
		do {
			pos0 = pos;
			pos = str.findFirstNotOf("\r\n", pos);
			if (pos < 0) break;
			if (str.substr(pos, 2) != "//" && str.substr(pos, 1) != "\t")
			{
				if (pos != kd.keyTop)
				{
					str.insert(pos, "//");
					if (kd.keyTop >= pos) kd.keyTop += 2;
					if (kd.valueTop >= pos) kd.valueTop += 2;
					pos += 2;
				}
			}
			pos = str.find("\n", pos);
		} while (pos > pos0);
		kd.areaStr = str;
	}
	
	void _parseKeyDataCst(KeyData &inout kd)
	{
		array<string> patterns = {
			"(?i)(?:^|\\n) *" + kd.key + " *= *(\\S[^\t\r\n]*)",	// specified value
			"(?i)(?:^|\\n) *" + kd.key + " *= *",	// empty value
			"(?i)(?:^|\\n)[^\t\r\n]*\\b" + kd.key + " *="	// comment out
		};
		
		if (kd.key.empty()) {kd.init(); return;}
		string str = kd.areaStr;
		if (str.empty()) {kd.init(); return;}
		
		string value;
		int keyTop = -1;
		int valueTop = -1;
		uint i;
		for (i = 0; i < 3; i++)
		{
			array<dictionary> match;
			if (tx.regExpParse(str, patterns[i], match, 0) >= 0)
			{
				int p0 = int(match[0]["pos"]);
				string s0 = string(match[0]["str"]);
				if (s0.Left(1) == "\n")
				{
					s0 = s0.substr(1);
					p0 += 1;
				}
				str.erase(p0, s0.length());
				str.insert(p0, kd.key + "=");
				keyTop = p0;
				valueTop = p0 + kd.key.length() + 1;
				if (i == 0)
				{
					value = string(match[1]["str"]);
					value.Trim();
					if (!value.empty())
					{
						str.insert(valueTop, value);
						break;
					}
				}
				else if (i == 1)
				{
					value = _getValue(kd.section, kd.key, 1);
					if (!value.empty())
					{
						str.insert(valueTop, value);
					}
					break;
				}
				else if (i == 2)
				{
					if (str.substr(keyTop, 2) != "//" && str.substr(keyTop, 1) != "\t")
					str.insert(keyTop, "//");
					value = _getValue(kd.section, kd.key, 1);
					if (!value.empty())
					{
						str.insert(keyTop, kd.key + "=" + value + "\r\n");
						kd.valueTop = keyTop + kd.key.length() + 1;
					}
					break;
				}
			}
		}
		
		kd.areaStr = str;
		kd.value = value;
		kd.state = i < 3 ? 1 : 0;
		kd.keyTop = keyTop;
		kd.valueTop = valueTop;
		
		_keyCommentOut(kd);
	}
	
	void __loadCst(string sectArea, string section)
	{
		dictionary _kds;
		array<string> keys;
		if (!keyNames.get(section, keys)) return;
		
		array<uint> tops;
		for (uint i = 0; i < keys.length(); i++)
		{
			string key = keys[i];
			if (key.Left(1) == "#") key = key.substr(1);	// hidden key
			KeyData kd(section, key);
			int pos = _findKeyTop(sectArea, key);
			if (pos >= 0)
			{
				kd.areaTop = pos;
				tops.insertLast(pos);
			}
			_kds.set(key, kd);
		}
		tops.sortAsc();
		
		for (uint i = 0; i < keys.length(); i++)
		{
			KeyData kd;
			string key = keys[i];
			if (key.Left(1) == "#") key = key.substr(1);	// hidden key
			if (_kds.get(key, kd))
			{
				if (kd.areaTop >= 0)
				{
					int idx = tops.find(kd.areaTop);
					if (idx < 0) continue;
					string keyArea;
					{
						// Find the top of the next keyArea and determine the current keyArea.
						idx++;	// next key
						uint _pos = (uint(idx) < tops.length()) ? tops[idx] : sectArea.length();
						int blnk = _findBlankLine(sectArea, kd.areaTop);
						if (_pos > uint(blnk)) _pos = blnk;
						keyArea = sectArea.substr(kd.areaTop, _pos - kd.areaTop);
					}
					{
						// Reflect the default description
						string keyAreaDef = _getCfgStrDefAll(section, key);
						int _pos = _findDescriptionTop(keyAreaDef);
						string desc = (_pos > 0) ? keyAreaDef.substr(_pos) : "\r\n";
						keyArea = _removeTabLine(keyArea);
						keyArea = _removeLastBlank(keyArea);
						keyArea += desc;
					}
					kd.areaStr = keyArea;
					kd.areaTop = -1;
				}
				else
				{
					// Add missing keys
					kd.areaStr = _getCfgStrDef(section, key);
				}
				_parseKeyDataCst(kd);
				_kds.set(key, kd);
			}
		}
		kdsCst.set(section, _kds);
	}
	
	void _loadCst(string str)
	{
		kdsCst = {};
		sectionNamesCst = {};
		array<string> sections = sectionNamesDef;
		if (sections.length() == 1 && sections[0] == "")
		{
			sectionNamesCst.insertLast("");
			string sectArea;
			if (str.Left(1) == "[")
			{
				sectArea = "";
			}
			else
			{
				sectArea = str.Left(_findSectionSepaNext(str, 0));
			}
			__loadCst(sectArea, "");
		}
		else
		{
			int pos = 0;
			int pos0;
			do {
				pos0 = pos;
				string section;
				string sectArea = _getSectionAreaNext(str, section, pos);
				if (pos >= 0)
				{
					if (!section.empty())
					{
						int idx = tx.findI(sections, section);
						if (idx >= 0)
						{
							section = sections[idx];	// Correct case difference
							sections.removeAt(idx);
							sectionNamesCst.insertLast(section);
							__loadCst(sectArea, section);
						}
					}
					pos += sectArea.length();
				}
			} while (pos > pos0);
			
			// Add the missing section
			for (uint i = 0; i < sections.length(); i++)
			{
				string sectAreaDef = _getCfgStrDef(sections[i]);
				if (!sectAreaDef.empty())
				{
					sectionNamesCst.insertLast(sections[i]);
					__loadCst(sectAreaDef, sections[i]);
				}
			}
		}
	}
	
	string _getCfgStr(int stateDef)
	{
		// stateDef - 0: cust / 1: def without hidden key / 2: def all
		
		dictionary kds;
		array<string> sections;
		if (stateDef > 0)
		{
			kds = kdsDef; sections = sectionNamesDef;
		}
		else
		{
			kds = kdsCst; sections = sectionNamesCst;
		}
		if (sections.length() == 0 || kds.empty()) return "";
		
		string str = "";
		for (uint i = 0; i < sections.length(); i++)
		{
			string section = sections[i];
			if (!section.empty())
			{
				str += "[" + section + "]\r\n\r\n";
			}
			array<string> keys;
			if (keyNames.get(section, keys))
			{
				for (uint j = 0; j < keys.length(); j++)
				{
					string key = keys[j];
					if (key.Left(1) == "#")	// hidden key
					{
						if (stateDef == 1) continue;
						else if (stateDef == 0) key = key.substr(1);
					}
					dictionary _kds;
					if (kds.get(section, _kds))
					{
						KeyData kd;
						if (_kds.get(key, kd))
						{
							str += kd.areaStr;
						}
					}
				}
			}
		}
		return str;
	}
	
	string _getCfgStrCst()
	{
		return _getCfgStr(0);
	}
	
	string _getCfgStrDef()
	{
		return _getCfgStr(1);
	}
	
	string _getCfgStrDefAll()
	{
		return _getCfgStr(2);
	}
	
	string _getCfgStr(int stateDef, string section)
	{
		// stateDef - 0: cust / 1: def without hidden key / 2: def all
		
		dictionary kds;
		array<string> sections;
		if (stateDef > 0)
		{
			kds = kdsDef; sections = sectionNamesDef;
		}
		else
		{
			kds = kdsCst; sections = sectionNamesCst;
		}
		if (sections.length() == 0 || kds.empty()) return "";
		
		string str = "";
		if (!section.empty())
		{
			str += "[" + section + "]\r\n\r\n";
		}
		array<string> keys;
		if (keyNames.get(section, keys))
		{
			for (uint j = 0; j < keys.length(); j++)
			{
				string key = keys[j];
				if (key.Left(1) == "#")	// hidden key
				{
					if (stateDef == 1) continue;
					else if (stateDef == 0) key = key.substr(1);
				}
				dictionary _kds;
				if (kds.get(section, _kds))
				{
					KeyData kd;
					if (_kds.get(key, kd))
					{
						str += kd.areaStr;
					}
				}
			}
		}
		return str;
	}
	
	string _getCfgStrCst(string section)
	{
		return _getCfgStr(0, section);
	}
	
	string _getCfgStrDef(string section)
	{
		return _getCfgStr(1, section);
	}
	
	string _getCfgStrDefAll(string section)
	{
		return _getCfgStr(2, section);
	}
	
	string _getCfgStr(int stateDef, string section, string key)
	{
		// stateDef - 0: cust / 1: def without hidden key / 2: def all
		
		if (key.Left(1) == "#" && stateDef != 1)
		{
			key = key.substr(1);	// hidden key
		}
		
		dictionary kds;
		array<string> sections;
		if (stateDef > 0)
		{
			kds = kdsDef;
			sections = sectionNamesDef;
		}
		else
		{
			kds = kdsCst;
			sections = sectionNamesCst;
		}
		if (sections.length() == 0 || kds.empty()) return "";
		
		string str = "";
		dictionary _kds;
		if (kds.get(section, _kds))
		{
			KeyData kd;
			if (_kds.get(key, kd))
			{
				str = kd.areaStr;
			}
			else if (stateDef == 2)
			{
				if (_kds.get("#" + key, kd))
				{
					str = kd.areaStr;
				}
			}
		}
		return str;
	}
	
	string _getCfgStrCst(string section, string key)
	{
		return _getCfgStr(0, section, key);
	}
	
	string _getCfgStrDef(string section, string key)
	{
		return _getCfgStr(1, section, key);
	}
	
	string _getCfgStrDefAll(string section, string key)
	{
		return _getCfgStr(2, section, key);
	}
	
	bool loadFile()
	{
		if (!_loadDef()) return false;
		
		string str0;
		uintptr fp = fc.openFileCst(str0);
		
		string str1 = str0;
		if (str1.empty()) str1 = _getCfgStrDef();
		_loadCst(str1);
		
		{
			// specific processes of each script
			int criticalError = getInt("MAINTENANCE", "critical_error");
			if (criticalError == 0)
			{
				deleteKey("MAINTENANCE", "critical_error", false);
			}
			if (criticalError != 0 || ytd.error > 0)
			{
				deleteKey("MAINTENANCE", "update_ytdlp", false);
			}
		}
		
		string str2 = _getCfgStrCst();
		
		fc.closeFileCst(fp, str2 != str0, str2);
		
		// specific properties of each script
		{
			csl = getInt("MAINTENANCE", "console_out");
			if (csl < 0 || csl > 3) csl = 0;
			
			baseLang = getStr("YOUTUBE", "base_lang");
			if (baseLang.empty())
			{
				baseLang = ytl.baseLang();
			}
			
			autoSubLangs.removeRange(0, autoSubLangs.length());
			string asLang = getStr("YOUTUBE", "auto_sub_lang");
			if (asLang.empty())
			{
				autoSubLangs = ytl.systemLang();
			}
			else
			{
				autoSubLangs = tx.trimSplit(asLang, ",");
			}
		}
		
		return true;
	}
	
	int saveFile()
	{
		string str0;
		uintptr fp = fc.openFileCst(str0);
		string str1 = _getCfgStrCst();
		return fc.closeFileCst(fp, str1 != str0, str1);
	}
	
	bool deleteKey(string section, string key, bool save = true)
	{
		dictionary _kds;
		if (kdsCst.get(section, _kds))
		{
			KeyData kd;
			if (_kds.get(key, kd))
			{
				kd.init();
				_kds.set(key, kd);
				kdsCst.set(section, _kds);
				if (save) saveFile();
				return true;
			}
		}
		return false;
	}
	
	bool deleteKey(string key, bool save = true)
	{
		return deleteKey("", key, save);
	}
	
	bool cmtoutKey(string section, string key, bool save = true)
	{
		dictionary _kds;
		if (kdsCst.get(section, _kds))
		{
			KeyData kd;
			if (_kds.get(key, kd))
			{
				if (kd.state == 1 && !kd.areaStr.empty() && kd.keyTop >= 0)
				{
					kd.state = 0;
					kd.areaStr.insert(kd.keyTop, "//");
					kd.valueTop = -1;
					kd.value = "";
					_kds.set(key, kd);
					kdsCst.set(section, _kds);
					if (save) saveFile();
					return true;
				}
			}
		}
		return false;
	}
	
	bool cmtoutKey(string key, bool save = true)
	{
		return cmtoutKey("", key, save);
	}
	
	string _getValue(string section, string key, int useDef)
	{
		// useDef
		// 0: kdsCst (with kdsDef if kdsCst is empty)
		// 1: kdsDef 
		// -1: kdsCst only
		
		dictionary kds = useDef == 1 ? kdsDef : kdsCst;
		dictionary _kds;
		if (kds.get(section, _kds))
		{
			KeyData kd;
			if (_kds.get(key, kd))
			{
				if (useDef != 0 || kd.state == 1) return kd.value;
			}
			else
			{
				if (useDef == 1 && key.Left(1) != "#")
				{
					return _getValue(section, "#" + key, 1);
				}
			}
		}
		return useDef == 0 ? _getValue(section, key, 1) : "";
	}
	
	string getStr(string section, string key, int useDef = 0)
	{
		return tx.escapeQuote(_getValue(section, key, useDef));
	}
	
	string getStr(string key, int useDef = 0)
	{
		return tx.escapeQuote(_getValue("", key, useDef));
	}
	
	int getInt(string section, string key, int useDef = 0)
	{
		return parseInt(_getValue(section, key, useDef));
	}
	
	int getInt(string key, int useDef = 0)
	{
		return parseInt(_getValue("", key, useDef));
	}
	
	string _setValue(string section, string key, string setValue, bool save)
	{
		dictionary _kds;
		if (kdsCst.get(section, _kds))
		{
			string prevValue = "";
			KeyData kd;
			if (_kds.get(key, kd))
			{
				if (kd.areaStr.empty())
				{
					kd.section = section;
					kd.key = key;
					kd.areaStr = _getCfgStrDefAll(section, key);
					if (kd.areaStr.Left(1) == "#") kd.areaStr = kd.areaStr.substr(1);
					_parseKeyDataCst(kd);
				}
				
				prevValue = kd.value;
				setValue.Trim();
				if (setValue.empty()) setValue = _getValue(section, key, 1);
				if (kd.state > 0)
				{
					if (kd.valueTop >= 0)
					{
						kd.areaStr.erase(kd.valueTop, prevValue.length());
						kd.areaStr.insert(kd.valueTop, setValue);
						kd.value = setValue;
						kd.state = 1;
					}
				}
				else
				{
					if (kd.keyTop >= 0)
					{
						kd.areaStr.insert(kd.keyTop, key + "=" + setValue + "\r\n");
						kd.valueTop = kd.keyTop + key.length() + 1;
						kd.value = setValue;
						kd.state = 1;
					}
				}
				
				_kds.set(key, kd);
				kdsCst.set(section, _kds);
				if (save) saveFile();
				return prevValue;
			}
		}
		return "";
	}
	
	string setStr(string section, string key, string sValue, bool save = true)
	{
		string prevValue = _setValue(section, key, sValue, save);
		return tx.escapeQuote(prevValue);
	}
	
	string setStr(string key, string sValue, bool save = true)
	{
		string prevValue = _setValue("", key, sValue, save);
		return tx.escapeQuote(prevValue);
	}
	
	int setInt(string section, string key, int iValue, bool save = true)
	{
		string prevValue = _setValue(section, key, formatInt(iValue), save);
		return parseInt(prevValue);
	}
	
	int setInt(string key, int iValue, bool save = true)
	{
		string prevValue = _setValue("", key, formatInt(iValue), save);
		return parseInt(prevValue);
	}
	
}

CFG cfg;

//----------------------- END of class CFG -------------------------


class TEXT
{
	
	int findI(string str, string search, int fromPos = 0)
	{
		// Case-insensitive search
		str.MakeLower();
		search.MakeLower();
		return str.find(search, fromPos);
	}
	
	int findI(array<string> arr, string search)
	{
		// Case-insensitive search in array
		for (uint i = 0; i < arr.length(); i++)
		{
			if (arr[i].MakeLower() == search.MakeLower()) return i;
		}
		return -1;
	}
	
	string qt(string str)
	{
		// Enclose in double quotes
		
		string endBackSlash = HostRegExpParse(str, "(\\\\+)$");
		if (endBackSlash.length() % 2 == 1)
		{
			// Prevent the end quote from being escaped by the back-slash
			str += "\\";
		}
		str = "\"" + str + "\"";
		return str;
	}
	
	string escapeQuote(string str)
	{
		// Do not use Trim("\"")
		if (str.length() > 1)
		{
			if (str.Left(1) == "\"" && str.Right(1) == "\"")
			{
				string _str = str.substr(1, str.length() - 2);
				if (_str.find("\"") < 0)
				{
					return _str;
				}
			}
		}
		str.replace("\\", "\\\\");
		str.replace("\"", "\\\"");
		return str;
	}
	
	string escapeReg(string str)
	{
		array<string> esc = {"\\", "|", ".", "+", "-", "*", "/", "^", "$", "(", ")", "[", "]", "{", "}"};
		for (uint i = 0; i < esc.length(); i++)
		{
			str.replace(esc[i], "\\" + esc[i]);
		}
		return str;
	}
	
	string _regLower(string reg)
	{
		// Avoid regular expressions
		string _reg = "";
		uint cnt = 0;
		for (uint pos = 0; pos < reg.length(); pos++)
		{
			string c = reg.substr(pos, 1);
			if (c == "\\")
			{
				cnt++;
				if (cnt == 4) cnt = 0;
			}
			else if (cnt > 0)
			{
				// just after "\\"
				cnt = 0;
			}
			else
			{
				c.MakeLower();
			}
			_reg += c;
		}
		return _reg;
	}
	
	int regExpParse(string str, string reg, array<dictionary> &match, int fromPos)
	{
		// Modify HostRegExpParse
		if (str.empty() || reg.empty() || match is null) return -1;
		if (fromPos < 0 || uint(fromPos) >= str.length()) return -1;
		string origStr = str;
		bool caseInsens = false;
		if (reg.Left(4) == "(?i)")
		{
			// Case-insensitive (not available for HostRegExpParse)
			caseInsens = true;
			reg = reg.substr(4);
			str.MakeLower();
			reg = _regLower(reg);
		}
		
		array<dictionary> _match;
		string _str = str.substr(fromPos);
		if (HostRegExpParse(_str, reg, _match))
		{
			int pos0 = -1;
			for (uint i = 0; i < _match.length(); i++)
			{
				string s1 = string(_match[i]["first"]);
				string s2 = string(_match[i]["second"]);
				int pos = _str.length() - s2.length() - s1.length();
				pos = fromPos + pos;
				{
					dictionary dic;
					if (!caseInsens)
					{
						dic["str"] = s1;
					}
					else
					{
						dic["str"] = origStr.substr(pos, s1.length());
					}
					dic["pos"] = pos;
					match.insertLast(dic);
					if (i == 0) pos0 = pos;
				}
			}
			return pos0;
		}
		return -1;
	}
	
	int findRegExp(string str, string reg, int fromPos = 0)
	{
		array<dictionary> match;
		int pos = regExpParse(str, reg, match, fromPos);
		if (pos >= 0)
		{
			if (match.length() > 1)
			{
				pos = int(match[1]["pos"]);
			}
			return pos;
		}
		return -1;
	}
	
	int findRegExp(string str, string reg, string &out getStr, int fromPos = 0)
	{
		array<dictionary> match;
		int pos = regExpParse(str, reg, match, fromPos);
		if (pos >= 0)
		{
			if (match.length() > 1)
			{
				pos = int(match[1]["pos"]);
				getStr = string(match[1]["str"]);
			}
			else
			{
				getStr = string(match[0]["str"]);
			}
			return pos;
		}
		return -1;
	}
	
	string getRegExp(string str, string reg, int fromPos = 0)
	{
		string getStr;
		array<dictionary> match;
		int pos = regExpParse(str, reg, match, fromPos);
		if (pos >= 0)
		{
			if (match.length() > 1)
			{
				getStr = string(match[1]["str"]);
			}
			else
			{
				getStr = string(match[0]["str"]);
			}
		}
		return getStr;
	}
	
	int findLineTop(string str, int pos)
	{
		if (pos < 0 || pos > int(str.length())) pos = str.length();
		if (pos == 0) return 0;
		pos = str.findLastOf("\n", pos - 1);
		if (pos < 0) return 0;
		return pos + 1;
	}
	
	int findEol(string str, int pos)
	{
		// Does not include EOL characters at the end
		if (pos < 0 || pos >= int(str.length())) return int(str.length());
		pos = str.find("\n", pos);
		if (pos < 0) return int(str.length());
		if (pos == 0) return 0;
		if (str.substr(pos - 1, 1) == "\r") pos -= 1;
		return pos;
	}
	
	string getLine(string str, int pos)
	{
		int pos1 = findLineTop(str, pos);
		int pos2 = findEol(str, pos);
		if (pos2 - pos1 > 0)
		{
			return str.substr(pos1, pos2 - pos1);
		}
		return "";
	}
	
	int findNextLineTop(string str, int pos)
	{
		if (pos < 0 || pos >= int(str.length())) return -1;
		pos = str.find("\n", pos);
		if (pos < 0) return -1;
		return pos + 1;
	}
	
	int findPrevLineTop(string str, int pos)
	{
		if (pos < 0 || pos > int(str.length())) pos = str.length();
		if (pos == 0) return -1;
		pos = str.findLast("\n", pos - 1);
		if (pos < 0) return -1;
		pos = findLineTop(str, pos);
		return pos;
	}
	
	void eraseLine(string &inout str, int pos)
	{
		if (pos >= 0 && pos <= int(str.length()))
		{
			int pos1 = findLineTop(str, pos);
			int pos2 = findNextLineTop(str, pos);
			if (pos2 < 0) pos2 = str.length();
			str.erase(pos1, pos2 - pos1);
		}
	}
	
	array<string> trimSplit(string data, string dlmt)
	{
		array<string> arr = data.split(dlmt);
		for (int i = 0; i < int(arr.length()); i++)
		{
			string item = arr[i].Trim();
			if (item.empty())
			{
				arr.removeAt(i);
				i--; continue;
			}
			arr[i] = item;
		}
		return arr;
	}
	
	bool isSameDesc(string s1, string s2)
	{
		s1.replace("\n", " ");
		s2.replace("\n", " ");
		return (s1 == s2);
	}
	
	uint _findCharaTop(string str, uint pos)
	{
		// For multi-byte codes of utf8
		for (uint i = 1; i <= 3; i++)
		{
			if (pos < i) break;
			string chr = str.substr(pos - i, 1);
			if (chr > "\xf0") return pos - i;
			else if (i <= 2 && chr > "\xe0") return pos - i;
			else if (i <= 1 && chr > "\xc0") return pos - i;
		}
		return pos;
	}
	
	string cutOffString(string source, uint len)
	{
		string cutoff;
		if (len == 0 || len >= source.length())
		{
			cutoff = source;
		}
		else
		{
			int pos = _findCharaTop(source, len);
			cutoff = source.Left(pos);
			if (source.substr(pos, 3) == "...") cutoff += " ";
			cutoff += "...";
		}
		return cutoff;
	}
	
	bool isCutOffString(string cutoff, string source)
	{
		// source: abcdefghi
		// cutoff: abcd...
		if (cutoff.Right(3) == "..." && !source.empty())
		{
			cutoff.replace("\n", " ");
			source.replace("\n", " ");
			if (source.find(cutoff) != 0)
			{
				cutoff = cutoff.Left(cutoff.length() - 3);
				if (source.find(cutoff) == 0)
				{
					return true;
				}
				else if (cutoff.Right(1) == " ")
				{
					cutoff = cutoff.Left(cutoff.length() - 1);
					if (source.substr(cutoff.length(), 3) == "...")
					{
						if (source.find(cutoff) == 0)
						{
							return true;
						}
					}
				}
			}
		}
		return false;
	}
	
	string omitDecimal(string desc, string dot, int allowedDigit = -1)
	{
		int pos = desc.find(dot);
		if (pos < 0) return desc;
		string decimal = desc.substr(pos + dot.length());
		if (int(decimal.length()) > allowedDigit)
		{
			desc = desc.Left(pos);
		}
		return desc;
	}
	
	string formatTime(int msecTime)
	{
		string minus = "";
		if (msecTime < 0)
		{
			msecTime *= -1;
			minus = "-";
		}
		int second = msecTime / 1000;
		int ms = msecTime % 1000;
		int hour = second / 3600;
		second = second % 3600;
		int minute = second / 60;
		second = second % 60;
		
		string fmt;
		fmt += minus;
		fmt += formatInt(hour, '0', 2);
		fmt += ":";
		fmt += formatInt(minute, '0', 2);
		fmt += ":";
		fmt += formatInt(second, '0', 2);
		fmt += ".";
		fmt += formatInt(ms, '0', 3);
		return fmt;
	}
	
	string decodeEntityRefs(string desc)
	{
		// decode entity names (only often used ones)
		desc.replace("&quot;", "\"");
		desc.replace("&apos;", "'");
		desc.replace("&amp;", "&");
		desc.replace("&lt;", "<");
		desc.replace("&gt;", ">");
		desc.replace("&nbsp;", " ");
		desc.replace("&shy;", " ");
		desc.replace("&copy;", "©");
		desc.replace("&reg;", "®");
		return desc;
	}
	
	string decodeUTF16BE(string encoded)
	{
		// decoded UTF-16BE -> UTF-8 string
		// \u092F\u0942\u091F\u094D\u092F\u0942\u092C -> यूट्यूब
		
		string output = "";
		int len = encoded.length();
		
		for (int i = 0; i < len; i++)
		{
			string pre = encoded.substr(i, 2);
			if (i < len - 5 && (pre == "\\u" || pre == "U+"))
			{
				string hex = encoded.substr(i + 2, 4);
				int code = _parseHex(hex);
				if (code < 0)	// Error
				{
					output += encoded.substr(i, 1);
				}
				else
				{
					output += _charCodeToString(code);
					i += 5;
				}
			}
			else
			{
				// ordinary character
				output += encoded.substr(i, 1);
			}
		}
		
		return output;
	}
	
	string decodeNumericCharRefs(string encoded)
	{
		// decode numeric character references in UTF8
		// &#84;&#252;&#114;&#107;&#231;&#101; -> Türkçe
		// &#28450;&#23383; -> 漢字
		
		string output = "";
		uint i = 0;
		
		while (i < encoded.length())
		{
			if (i < encoded.length() - 2 && encoded.substr(i, 2) == "&#")
			{
				uint start = i;
				i += 2;
				
				bool isHex = false;
				if (i < encoded.length() && encoded.substr(i, 1).MakeLower() == "x")
				{
					isHex = true;
					i++;
				}
				
				int code;
				uint numStart = i;
				while (i < encoded.length() && encoded.substr(i, 1) != ";") i++;
				if (i < encoded.length() && encoded.substr(i, 1) == ";")
				{
					string numStr = encoded.substr(numStart, i - numStart);
					if (numStr.length() > 0)
					{
						if (isHex)
						{
							code = _parseHex(numStr);
						}
						else
						{
							code = parseInt(numStr);
						}
						if (code >= 0 && code <= 0x10FFFF)
						{
							output += _charCodeToString(code);
							i++;	// skip semicolon
							continue;
						}
					}
				}
				output += encoded.substr(start, i - start + 1);
			}
			else
			{
				// ordinary character
				output += encoded.substr(i, 1);
			}
			i++;
		}
		return output;
	}
	
	int _parseHex(string hex)
	{
		hex.MakeLower();
		
		uint output = 0;
		for (uint i = 0; i < hex.length(); i++)
		{
			int digit = 0;
			uint8 code = hex[i];
			
			if (code >= _charToCode("0") && code <= _charToCode("9"))
				digit = code - _charToCode("0");
			else if (code >= _charToCode("a") && code <= _charToCode("f"))
				digit = code - _charToCode("a") + 10;
			else
				return -1; // invalid
			
			output = output * 16 + digit;
		}
		return output;
	}
	
	uint _charToCode(string ch)
	{
		// Handle only a single byte string
		if (ch.length() == 1) return ch[0];
		return 0;
	}
	
	string _charCodeToString(int code)
	{
		// character code -> UTF-8 string
		
		string hex = formatInt(code, "x");
		while (hex.length() < 4) hex = "0" + hex;
		
		if (code <= 0x7F)
		{
			// 1 bite code: 0xxxxxxx
			string output = " ";
			output[0] = code;
			return output;
		}
		else if (code <= 0x7FF)
		{
			// 2 bite code: 110xxxxx 10xxxxxx
			string output = "  ";
			output[0] = 0xC0 | (code >> 6);
			output[1] = 0x80 | (code & 0x3F);
			return output;
		}
		else if (code <= 0xFFFF)
		{
			// 3 bite code: 1110xxxx 10xxxxxx 10xxxxxx
			string output = "   ";
			output[0] = 0xE0 | (code >> 12);
			output[1] = 0x80 | ((code >> 6) & 0x3F);
			output[2] = 0x80 | (code & 0x3F);
			return output;
		}
		else if (code <= 0x10FFFF)
		{
			// 4 bite code: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
			string output = "    ";
			output[0] = 0xF0 | (code >> 18);
			output[1] = 0x80 | ((code >> 12) & 0x3F);
			output[2] = 0x80 | ((code >> 6) & 0x3F);
			output[3] = 0x80 | (code & 0x3F);
			return output;
		}
		
		return "";
	}
	
}

TEXT tx;

//----------------------- END of class TEXT -------------------------



class POTPLAYER
{

	string playerExePath;
	
	bool getPlayerExePath()
	{
		if (!playerExePath.empty()) return true;
		
		if (HostGetExecuteFolder() != HostGetConfigFolder())
		{
			// standard installation (useing the "Program Files" folder)
			
			array<string> folders = HostGetConfigFolder().split("\\");
			if (folders.length() == 6)
			{
				if (folders[4] == "Roaming" && !folders[5].empty())
				{
					string name = folders[5] + ".exe";
					
					string path = HostGetExecuteFolder() + name;
					if (HostFileExist(path))
					{
						playerExePath = path;
						return true;
					}
				}
			}
		}
		else
		{
			// portable installation
			
			string list = HostExecuteProgram("cmd.exe", "/c dir \"" + HostGetExecuteFolder() + "*.exe\" /b");
			
			array<string> exeNames;
			int pos = 0;
			while (true)
			{
				string name = tx.getLine(list, pos);
				if (!name.empty())
				{
					if (_isPotplayerExe(name))
					{
						exeNames.insertLast(name);
					}
					pos += name.length() + 2;
					continue;
				}
				break;
			}
			
			if (exeNames.length() == 1)
			{
				playerExePath = HostGetExecuteFolder() + exeNames[0];
				return true;
			}
			else if (exeNames.length() > 1)
			{
				// No way to identify which exe-name is currently used.
				// Prioritize the Mini build.
				string stdName = "PotPlayerMini";
				if (HostIsWin64()) stdName += "64";
				stdName += ".exe";
				for (int i = 0; i < 2; i++)
				{
					int n = tx.findI(exeNames, stdName);
					if (n >= 0)
					{
						playerExePath = HostGetExecuteFolder() + exeNames[n];
						return true;
					}
					stdName.replace("Mini", "");
				}
				for (uint i = 0; i < exeNames.length(); i++)
				{
					if (tx.findI(exeNames[i], "Mini") >= 0)
					{
						playerExePath = HostGetExecuteFolder() + exeNames[i];
						return true;
					}
				}
				playerExePath = HostGetExecuteFolder() + exeNames[0];
				return true;
			}
		}
		
		return false;
	}
	
	
	bool _isPotplayerExe(string name)
	{
		FileVersion fileInfo;
		if (fileInfo.Open(HostGetExecuteFolder() + name))
		{
			if (fileInfo.GetProductName() == "PotPlayer")
			{
				if (fileInfo.GetFileDescription() == "PotPlayer")
				{
					if (fileInfo.GetOriginalFilename() == "PotPlayer")
					{
						return true;
					}
				}
			}
		}
		return false;
	}
	
	
	bool playerAddList(string url, int playlistExpandMode = 0)
	{
		if (getPlayerExePath())
		{
			string options;
			options = "\"" + url + "\"";
			
			if (playlistExpandMode == 10)
			{
				options += " /new";	// add to the queue album of the new window
			}
			else
			{
				options += " /current";	// current window
			}
			
			if (playlistExpandMode == 0)
			{
				// add to the "default" album
			}
			else if (playlistExpandMode == 1)
			{
				options += " /add";	// add to the current album
			}
			else if (playlistExpandMode == 2)
			{
				options += " /insert";	// insert to the current album
				// This has an issue in the external-playlist album.
			}
			
			HostExecuteProgram(tx.qt(playerExePath), options);
			
			return true;
		}
		
		if (cfg.csl > 0)
		{
			HostPrintUTF8("[yt-dlp] Cannot find PotPlsyer's exe file name.\r\n");
		}
		return false;
	}
	
}

POTPLAYER pot;

//----------------------- END of class POTPLAYER -------------------------



class YT_LANG
{
	array<string> YT_BASE_LNAGS = {
		"af", "az", "id", "ms", "bs", "ca", "cs", "da", "de", "et",
		"en-IN", "en-GB", "en", "es", "es-419", "es-US", "eu", "fil",
		"fr", "fr-CA", "gl", "hr", "zu", "is", "it", "sw", "lv",
		"lt", "hu", "nl", "no", "uz", "pl", "pt-PT", "pt", "ro",
		"sq", "sk", "sl", "sr-Latn", "fi", "sv", "vi", "tr", "be",
		"bg", "ky", "kk", "mk", "mn", "ru", "sr", "uk", "el", "hy",
		"iw", "ur", "ar", "fa", "ne", "mr", "hi", "as", "bn", "pa",
		"gu", "or", "ta", "te", "kn", "ml", "si", "th", "lo", "my",
		"ka", "am", "km", "zh-CN", "zh-TW", "zh-HK", "ja", "ko"
	};
	
	array<string> YT_RTL_LNAGS = {
		"ar", "fa", "ur", "iw", "ps", "sd", "ug", "dv", "yi", "he"
	};
	
	array<string> systemLang()
	{
		array<string> langs = {};
		
		string _lang = HostIso639LangName();
		
		// Modify for YouTube
		if (_lang == "he")	// Hebrew
		{
			langs.insertLast("iw");
		}
		else if (_lang == "tl")	// Filipino
		{
			langs.insertLast("fil");
		}
		
		langs.insertLast(_lang);
		return langs;
	}
	
	string baseLang()
	{
		string baseLang = systemLang()[0];
		string langTag = baseLang + "-" + HostIso3166CtryName();
		if (langTag.Left(3) == "es-")
		{
			if (langTag != "es-ES" && langTag != "es-US" && langTag != "es-GQ")
			{
				langTag = "es-419";
			}
		}
		if (YT_BASE_LNAGS.find(langTag) >= 0)
		{
			baseLang = langTag;
		}
		else if (YT_BASE_LNAGS.find(baseLang) < 0)
		{
			baseLang = "en";
		}
		return baseLang;
	}
	
	bool isLangRTL(string langCode)
	{
		int pos = langCode.find("-");
		if (pos >= 0) langCode = langCode.Left(pos);
		if (YT_RTL_LNAGS.find(langCode) >= 0) return true;
		return false;
	}
}

YT_LANG ytl;

//----------------------- END of class YT_LANG -------------------------



class SPONSOR_BLOCK
{
	array<string> CATEGORIES = {
		"music_offtopic",	// Non-Music Section
		"outro",		// Endcards/Credits
		"intro",		// Intermission/Intro Animation
		"preview",		// Preview/Recap
		"hook",			// Hook/Greetings
		"filler",		// Filler Tangent (Tangents/Jokes)
		"selfpromo",		// Unpaid/Self Promotion
		"interaction",		// Interaction Reminder
		"sponsor",		// Sponsor
		"poi_highlight"		// Highlight
	};
		// The lower a category is on the list, the higher its priority.
	
	int THRSH_TIME = 2000;
		// Threshold time for SponsorBlock (milliseconds)
	
	string reviseChapter(string chptTitle)
	{
		// For SponsorBlock
		string prefix = "SB";
		if (chptTitle.find("Highlight") >= 0)
		{
			// Highlight is used differently from the other categories
			prefix += "-";
		}
		else
		{
			prefix += "/";
		}
		chptTitle = "<" + prefix + chptTitle + ">";
		return chptTitle;
	}
	
	uint removeChapterRange(array<dictionary> &chapterList, int msecTime1, int msecTime2, string &out chptTitle2, bool csl)
	{
		int nearTime1 = _findChapterNear(chapterList, msecTime1);
		if (nearTime1 < 0) nearTime1 = msecTime1;
		int nearTime2 = _findChapterNear(chapterList, msecTime2, chptTitle2);
		if (nearTime2 < 0) nearTime2 = msecTime2;
		
		uint cnt = 0;
		for (int i = 0; i < int(chapterList.length()); i++)
		{
			dictionary chapter = chapterList[i];
			int time0 = parseInt(string(chapter["time"]));
			if (time0 >= nearTime1 && time0 <= nearTime2)
			{
				chapterList.removeAt(i);
				cnt++;
				if (csl)
				{
					string title0 = string(chapter["title"]);
					HostPrintUTF8("Chapter Removed:  [" + tx.formatTime(time0) + "] " + title0);
				}
				i--; continue;
			}
		}
		return cnt;
	}
	
	int _findChapterNear(array<dictionary> chapterList, int time)
	{
		// time: milliseconds
		int nearTime = -1;
		int d0 = -1;
		for (uint i = 0; i < chapterList.length(); i++)
		{
			dictionary chapter = chapterList[i];
			int time0 = parseInt(string(chapter["time"]));
			if (time0 > time - THRSH_TIME && time0 < time + THRSH_TIME)
			{
				int d = time - time0;
				if (d < 0) d *= -1;
				if (d0 < 0 || d < d0)
				{
					d0 = d;
					nearTime = time0;
				}
			}
		}
		return nearTime;
	}
	
	int _findChapterNear(array<dictionary> chapterList, int time, string &out inheritTitle)
	{
		// time: milliseconds
		int nearTime = -1;
		int d0 = -1;
		for (uint i = 0; i < chapterList.length(); i++)
		{
			dictionary chapter = chapterList[i];
			int time0 = parseInt(string(chapter["time"]));
			if (time0 < time + THRSH_TIME)
			{
				int d = time - time0;
				if (d < 0) d *= -1;
				if (d0 < 0 || d < d0)
				{
					d0 = d;
					inheritTitle = string(chapter["title"]);
					if (d < THRSH_TIME) nearTime = time0;
				}
			}
		}
		return nearTime;
	}
	
}

SPONSOR_BLOCK sb;

//----------------------- END of class SPONSOR_BLOCK -------------------------



class SHOUTPL
{
	
	string _reviseName(string title)
	{
		string hidden = HostRegExpParse(title, "^(\\(#\\d[^)]+\\) ?)");
		if (!hidden.empty()) title = title.substr(hidden.length());
		return title;
	}
	
	string _getFormat(string fmtUrl, uint i)
	{
		string format = "#" + i;
		int pos = fmtUrl.findLast("/");
		if (pos > 0) format += ": " + fmtUrl.substr(pos + 1);
		return format;
	}
	
	uint _setItag(void)
	{
		uint itag = 1;
		while (HostExistITag(itag)) itag++;
		HostSetITag(itag);
		return itag;
	}
	
	string _parsePls(string data, string &out getTitle, array<dictionary> &QualityList)
	{
		// For Shoutcast pls playlist
		string outUrl;
		for (uint i = 0; i < 20; i++)
		{
			string title = http.getDataField(data, "Title" + (i + 1), "=");
			if (!title.empty())
			{
				title = _reviseName(title);
				if (i == 0) getTitle = title;
				else if (title != getTitle) break;
			}
			string fmtUrl = http.getDataField(data, "File" + (i + 1), "=");
			if (fmtUrl.empty()) break;
			if (outUrl.empty()) outUrl = fmtUrl;
			
			if (@QualityList !is null)
			{
				dictionary Quality;
				Quality["url"] = fmtUrl;
				Quality["format"] = _getFormat(fmtUrl, i);
				Quality["itag"] = _setItag();
				QualityList.insertLast(Quality);
			}
		}
		return outUrl;
	}
	
	string _parseM3u(string data, string &out getTitle, array<dictionary> &QualityList)
	{
		// For Shoutcast m3u playlist
		
		string outUrl;
		int pos = 0;
		for (uint i = 0; i < 20; i++)
		{
			array<dictionary> match;
			pos = tx.regExpParse(data, "(?:^|\\n)#EXTINF:(?:[^,\r\n]*),([^,\r\n]*)\\r?\\n([^\r\n]+)\\r?\\n", match, pos);
			if (pos < 0) break;
			
			string s0 = string(match[0]["str"]);
			pos += s0.length();
			string title = string(match[1]["str"]);
			{
				title = _reviseName(title);
				if (i == 0) getTitle = title;
				else if (title != getTitle) break;
			}
			string fmtUrl = string(match[2]["str"]);
			if (outUrl.empty()) outUrl = fmtUrl;
			
			if (@QualityList !is null)
			{
				dictionary Quality;
				Quality["url"] = fmtUrl;
				Quality["format"] = _getFormat(fmtUrl, i);
				Quality["itag"] = _setItag();
				QualityList.insertLast(Quality);
			}
		}
		return outUrl;
	}
	
	string _parseXspf(string data, string &out getTitle, array<dictionary> &QualityList)
	{
		// For Shoutcast xspf playlist
		
		string outUrl;
		data.replace("\n", ""); data.replace("\r", "");
		int pos = 0;
		for (uint i = 0; i < 20; i++)
		{
			array<dictionary> match;
			pos = tx.regExpParse(data, "<track>(.+?)</track>", match, pos);
			if (pos < 0) break;
			
			string s0 = string(match[0]["str"]);
			pos += s0.length();
			string track = string(match[1]["str"]);
			string title = HostRegExpParse(track, "<title>(.+?)</title>");
			{
				title = _reviseName(title);
				if (i == 0) getTitle = title;
				else if (title != getTitle) break;
			}
			string fmtUrl = HostRegExpParse(track, "<location>(.+?)</location>");
			if (outUrl.empty()) outUrl = fmtUrl;
			
			if (@QualityList !is null)
			{
				dictionary Quality;
				Quality["url"] = fmtUrl;
				Quality["format"] = _getFormat(fmtUrl, i);
				Quality["itag"] = _setItag();
				QualityList.insertLast(Quality);
			}
		}
		return outUrl;
	}
	
	string parse(string url, dictionary &MetaData, array<dictionary> &QualityList, bool addLocation)
	{
		string ext = HostRegExpParse(url, "/tunein-station\\.(pls|m3u|xspf)\\?");
		if (!ext.empty())
		{
			string data = http.getContent(url, 5, 4095);
			if (!data.empty())
			{
				string outUrl;
				string title;
				if (ext == "pls") outUrl = _parsePls(data, title, QualityList);
				if (ext == "m3u") outUrl = _parseM3u(data, title, QualityList);
				if (ext == "xspf") outUrl = _parseXspf(data, title, QualityList);
				
				if (!outUrl.empty())
				{
					MetaData["playUrl"] = outUrl;
					MetaData["url"] = url;
					MetaData["webUrl"] = url;
					title = _ReviseWebString(title);
					title = _CutOffString(title);
					MetaData["title"] = title;
						// station name that will be replaced to a current music title after playback starts
					MetaData["author"] = title + (addLocation ? " @ShoutcastPL" : "");
					MetaData["vid"] = HostRegExpParse(url, "\\?id=(\\d+)");
					MetaData["fileExt"] = ext;
					if (cfg.getInt("TARGET", "radio_thumbnail") == 1)
					{
						MetaData["thumbnail"] = _GetRadioThumb("shoutcast");
					}
					return outUrl;
				}
			}
		}
		return "";
	}
	
	void passPlaylist(string url, array<dictionary> &MetaDataList)
	{
		dictionary MetaData;
		MetaData["url"] = url;
		MetaData["thumbnail"] = _GetRadioThumb("shoutcast");
		MetaDataList.insertLast(MetaData);
	}
	
	uint extractPlaylist(string url, array<dictionary> &MetaDataList)
	{
		MetaDataList = {};
		dictionary _MetaData;
		array<dictionary> _QualityList;
		if (!parse(url, _MetaData, _QualityList, false).empty())
		{
			string etrTitle = string(_MetaData["title"]);
			string etrAuthor = string(_MetaData["author"]);
			string etrThumb = string(_MetaData["thumbnail"]);
			for (uint i = 0; i < _QualityList.length(); i++)
			{
				dictionary MetaData;
				MetaData["url"] = string(_QualityList[i]["url"]);
				MetaData["title"] = etrTitle;
				MetaData["author"] = etrAuthor;
				MetaData["thumbnail"] = etrThumb;
				MetaDataList.insertLast(MetaData);
			}
			return MetaDataList.length();
		}
		return 0;
	}
	
}

SHOUTPL shoutpl;

//----------------------- END of class SHOUTPL -------------------------



class JSON
{
	
	string dictionaryToJson(dictionary &dic)
	{
		string json = "{";
		array<string>@ keys = dic.getKeys();
		
		for (uint i = 0; i < keys.length(); i++)
		{
			string key = keys[i];
			json += "\"" + key + "\": ";
			
			array<dictionary> dicList;
			if (dic.get(key, dicList))
			{
				json += dictionaryListToJson(dicList);
			}
			else
			{
				string sValue;
				if (dic.get(key, sValue))
				{
					sValue.replace("\\", "\\\\");
					sValue.replace("\"", "\\\"");
					json += "\"" + sValue + "\"";
				}
				else
				{
					int iValue;
					if (dic.get(key, iValue))
					{
						json += iValue;
					}
					else
					{
						float fValue;
						if (dic.get(key, fValue))
						{
							json += fValue;
						}
						else
						{
							bool bValue;
							if (dic.get(key, bValue))
							{
								json += bValue;
							}
						}
					}
				}
			}
			if (i < keys.length() - 1) json += ", ";
		}
		
		json += "}";
		return json;
	}
	
	string dictionaryListToJson(array<dictionary> &dicList)
	{
		string json = "[";
		
		for (uint i = 0; i < dicList.length(); i++)
		{
			dictionary dic = dicList[i];
			json += dictionaryToJson(dic);
			if (i < dicList.length() - 1) json += ", ";
		}
		
		json += "]";
		return json;
	}
	
	dictionary jsonToDictionary(string json)
	{
		JsonReader reader;
		JsonValue root;
		if (reader.parse(json, root) && root.isObject())
		{
			return jsonToDictionary(root);
		}
		return {};
	}
	
	dictionary jsonToDictionary(JsonValue &parent)
	{
		dictionary dic = {};
		array<string>@ keys = parent.getKeys();
		
		for (uint i = 0; i < keys.length(); i++)
		{
			string key = keys[i];
			JsonValue value = parent[key];
			
			if (value.isArray())
			{
				dic[key] = jsonToDictionaryList(value);
			}
			else if (value.isObject())
			{
				dic[key] = jsonToDictionary(value);
			}
			else if (value.isString())
			{
				string str = value.asString();
				str.replace("\\\"", "\"");
				str.replace("\\\\", "\\");
				dic[key] = str;
			}
			else if (value.isInt())
			{
				dic[key] = value.asInt();
			}
			else if (value.isFloat())
			{
				dic[key] = value.asFloat();
			}
			else if (value.isBool())
			{
				dic[key] = value.asBool();
			}
		}
		
		return dic;
	}
	
	array<dictionary> jsonToDictionaryList(string json)
	{
		JsonReader reader;
		JsonValue root;
		if (reader.parse(json, root) && root.isArray())
		{
			return jsonToDictionaryList(root);
		}
		return {};
	}
	
	array<dictionary> jsonToDictionaryList(JsonValue &parent)
	{
		if (!parent.isArray()) return {};
		
		array<dictionary> dicList = {};
		for (int i = 0; i < parent.size(); i++)
		{
			dictionary dic = jsonToDictionary(parent[i]);
			dicList.insertLast(dic);
		}
		return dicList;
	}
	
	bool getValueString(JsonValue parent, string key, string &out sValue)
	{
		sValue = "";
		JsonValue value = parent[key];
		if (value.isString())
		{
			sValue = value.asString();
			return true;
		}
		return false;
	}
	
	bool getValueInt(JsonValue parent, string key, int &out iValue)
	{
		iValue = 0;
		JsonValue value = parent[key];
		if (value.isInt())
		{
			iValue = value.asInt();
			return true;
		}
		return false;
	}
	
	bool getValueFloat(JsonValue parent, string key, float &out fValue)
	{
		fValue = 0;
		JsonValue value = parent[key];
		if (value.isFloat())
		{
			fValue = value.asFloat();
			return true;
		}
		return false;
	}
	
	bool getValueBool(JsonValue parent, string key, bool &out bValue)
	{
		bValue = false;
		JsonValue value = parent[key];
		if (value.isBool())
		{
			bValue = value.asBool();
			return true;
		}
		return false;
	}
	
	string getDirectValueString(string json, string key)
	{
		// For key="url"
		// The structural analysis is not accurate.
		
		key = tx.escapeReg(key);
		string str = HostRegExpParse(json, "\"" + key +"\":\\s?\"([^\"]+)\"");
		return str;
	}
	
	int getDirectValueInt(string json, string key)
	{
		key = tx.escapeReg(key);
		int num = parseInt(HostRegExpParse(json, "\"" + key +"\":\\s?(-?\\d+)"));
		return num;
	}
	
	string getDirectValueString(string json, string key1, string key2)
	{
		// For key1="thumbnails", key2 = "url"
		// The structural analysis is not accurate.
		
		key1 = tx.escapeReg(key1);
		key2 = tx.escapeReg(key2);
		string key1Area = HostRegExpParse(json, "\"" + key1 + "\":\\s?\\[(.+?)\\]");
		if (key1Area.empty())
		{
			key1Area = HostRegExpParse(json, "\"" + key1 + "\":\\s?\\{(.+?)\\}");
		}
		if (!key1Area.empty())
		{
			string value = "";
			string _value;
			int pos = 0;
			while (true)
			{
				pos = tx.findRegExp(key1Area, "\"" + key2 + "\":\\s?\"(.+?)\"", _value, pos);
				if (pos < 0) break;
				value = _value;
				pos += 1;
			}
			return value;
		}
		return "";
	}
	
}

JSON jsn;

//----------------------- END of class JSON -------------------------



class HTTP
{
	
	int noCurl = 0;
	
	string getContent(string url, int maxTime, int range, bool isInsecure)
	{
		// Uses curl command
		
		string options = "";
		if (maxTime > 0)
		{
			options += " --max-time " + maxTime;
		}
		if (range < 0)
		{
			options += " -I";	// get header
		}
		else if (range > 0)
		{
			options += " -r 0-" + range;
			// Not available for dynamic pages that change playlists
		}
		//options += " --max-filesize " + fileSize;
		if (isInsecure)
		{
			options += " -k";
		}
		//options += " -A " + USER_AGENT;
		//options += " --referer " + referer;
		options += " -L --max-redirs 3";	// redirect
		options += " -s";
		options += " \"" + url + "\"";
		string data = HostExecuteProgram("curl", options);
		
		if (data.empty())
		{
			if (noCurl == 0)
			{
				string ver = HostExecuteProgram("curl", "-V");
				if (ver.empty()) noCurl = 1;
			}
		}
		else
		{
			noCurl = 0;
		}
		
		if (noCurl > 0)
		{
			if (cfg.csl > 0)
			{
				HostPrintUTF8("\r\n[yt-dlp] CAUTION: \"curl.exe\" is not found.\r\n");
			}
		}
		else
		{
			if (cfg.csl == 3)
			{
				uint maxLen = 100000;
				HostPrintUTF8("\r\n http " + (range < 0 ? "header" : "content") + " -------------------");
				if (data.length() > maxLen)
				{
					HostPrintUTF8(data.substr(0, maxLen) + "...\r\n(-------- omitted --------)\r\n\r\n");
				}
				else
				{
					HostPrintUTF8(data);
					HostPrintUTF8("\r\n--------------------------\r\n\r\n");
				}
			}
		}
		
		if (!data.empty())
		{
			// Get only the last header if data includes multiple headers with redirect
			int pos1;
			int pos2 = 0;
			do {
				pos1 = pos2;
				pos2 = tx.findRegExp(data, "(?i)\n\r?\n(HTTP)", pos1);
			} while (pos2 > pos1);
			data = data.substr(pos1);
			
		}
		
		return data;
	}
	
	string getContent(string url, int maxTime, int range)
	{
		bool isInsecure = (cfg.getInt("NETWORK", "no_check_certificates") == 1);
		return getContent(url, maxTime, range, isInsecure);
	}
	
	string getHeader(string url, int maxTime, bool isInsecure)
	{
		return getContent(url, maxTime, -1, isInsecure);
	}
	
	string getHeader(string url, int maxTime)
	{
		bool isInsecure = (cfg.getInt("NETWORK", "no_check_certificates") == 1);
		return getHeader(url, maxTime, isInsecure);
	}
	
	
	string getDataField(string data, string field, string delimiter = ":")
	{
		// Each field is split by line break
		field = tx.escapeReg(field);
		string value = tx.getRegExp(data, "(?i)(?:^|\\n)" + field + delimiter + " *([^\r\n]+)");
		return value;
	}
	
}

HTTP http;

//---------------------- END of class YTDLP ------------------------



class CACHE
{
	array<dictionary> list;
	uint lifeTimeItem;
	uint lifeTimePlaylist;
	uint lifeTimeShort;
	uint maxSize = 1000000;	// for 32-bit PotPlayer
	uint totalSize = 0;
	
	void clear()
	{
		list.resize(0);
		
		if (HostIsWin64())
		{
			maxSize *= 10;	// for 64-bit PotPlayer
		}
		
		int _lifeTimeItem = cfg.getInt("NETWORK", "cache_time_item");	// minutes
		if (_lifeTimeItem < 0)
		{
			_lifeTimeItem = cfg.getInt("NETWORK", "cache_time_item", 1);
			cfg.setInt("NETWORK", "cache_time_item", _lifeTimeItem);
		}
		lifeTimeItem = uint(_lifeTimeItem * 60 * 1000);	// milliseconds
		
		int _lifeTimePlaylist = cfg.getInt("NETWORK", "cache_time_playlist");	// hours
		if (lifeTimePlaylist < 0)
		{
			_lifeTimePlaylist = cfg.getInt("NETWORK", "cache_time_playlist", 1);
			cfg.setInt("NETWORK", "cache_time_playlist", _lifeTimePlaylist);
		}
		lifeTimePlaylist = uint(_lifeTimePlaylist * 60 * 60 * 1000);	// milliseconds
		
		if (lifeTimePlaylist == 0 || lifeTimePlaylist > lifeTimeItem)
		{
			lifeTimeShort = lifeTimeItem;
		}
		else
		{
			lifeTimeShort = lifeTimePlaylist;
		}
	}
	
	int find(string url, string key = "")
	{
		for (uint i = 0; i < list.length(); i++)
		{
			string prevUrl = string(list[i]["url"]);
			if (prevUrl == url)
			{
				if (key.empty() || list[i].exists(key))
				{
					return i;
				}
			}
		}
		return -1;
	}
	
	void remove(int idx)
	{
		if (idx >= 0 && idx < int(list.length()))
		{
			totalSize -= int(list[idx]["size"]);
			list.removeAt(idx);
		}
	}
	
	void remove(string url, string key = "")
	{
		// Remove a record with the same url
		while (true)
		{
			int idx = find(url, key);
			if (idx < 0) break;
			remove(idx);
		}
	}
	
	void removeOld()
	{
		// Remove old list
		
		if (list.length() > 0)
		{
			uint curTime = HostGetTickCount();
			
			for (int i = int(list.length()) - 1; i >= 0; i--)
			{
				uint prevTime = int(list[i]["time"]);
				if (curTime < prevTime || totalSize > maxSize)
				{
					remove(i);
				}
				else 
				{
					uint lifeTime;
					if (list[i].exists("MetaDataList"))
					{
						lifeTime = lifeTimePlaylist;
					}
					else
					{
						lifeTime = lifeTimeItem;
					}
					if (lifeTime > 0 && curTime - prevTime >= lifeTime)
					{
						remove(i);
					}
					else
					{
						if (lifeTime == lifeTimeShort)
						{
							break;
						}
					}
				}
			}
		}
	}
	
	void addJson(string url, string json, string imgUrl = "")
	{
		if (json.empty()) return;
		removeOld();
		
		if (find(url) >= 0) return ;
		
		// Add a new record
		dictionary rec;
		rec["url"] = url;
		rec["time"] = HostGetTickCount();
		
		string gzJson = HostGzipCompress(json);
		rec["json"] = gzJson;
		
		if (!imgUrl.empty())
		{
			rec["imgUrl"] = imgUrl;
		}
		
		int size = gzJson.length();
		rec["size"] = size;
		totalSize += size;
		list.insertAt(0, rec);
		
		if (cfg.csl > 1)
		{
			if (json.length() > 0)
			{
				if (false)
				{
					int compRate = int(float(gzJson.length()) / float(json.length()) * 100);
					HostPrintUTF8("Compression rate (temporary JSON): " + compRate + "%");
				}
				if (false)
				{
					string msg = "Cache size (temporary JSON): ";
					msg += (size / 1024) + " / " + (totalSize / 1024) + " KB";
					msg += " - " + tx.qt(url) + "\r\n";
					HostPrintUTF8(msg);
				}
			}
		}
	}
	
	void addItem(string url, dictionary &MetaData, array<dictionary> &QualityList, bool edit = false)
	{
		if (MetaData.empty()) return;
		removeOld();
		
		int idx = find(url, "MetaData");
		if (idx >= 0)
		{
			if (!edit) return;
			remove(idx);
		}
		int idxJson = find(url, "json");
		if (idxJson >= 0) remove(idxJson);
		
		// Add a new record
		dictionary rec;
		rec["url"] = url;
		rec["time"] = HostGetTickCount();
		
		string sMetaData = jsn.dictionaryToJson(MetaData);
		string gzMetaData = HostGzipCompress(sMetaData);
		rec["MetaData"] = gzMetaData;
		
		string gzQualityList, sQualityList;
		if (@QualityList !is null)
		{
			sQualityList = jsn.dictionaryListToJson(QualityList);
			gzQualityList = HostGzipCompress(sQualityList);
			rec["QualityList"] = gzQualityList;
		}
		
		int size = gzMetaData.length() + gzQualityList.length();
		rec["size"] = size;
		totalSize += size;
		list.insertAt(0, rec);
		
		if (cfg.csl > 1)
		{
			if (false && sMetaData.length() > 0)
			{
				int compRate1 = int(float(gzMetaData.length()) / float(sMetaData.length()) * 100);
				HostPrintUTF8("Compression rate (MetaData): " + compRate1 + "%");
			}
			if (false && sQualityList.length() > 0)
			{
				int compRate2 = int(float(gzQualityList.length()) / float(sQualityList.length()) * 100);
				HostPrintUTF8("Compression rate (QualityList): " + compRate2 + "%");
			}
			string msg = "Cache size (MetaData & QualityList): ";
			msg += (size / 1024) + " / " + (totalSize / 1024) + " KB";
			msg += " - " + tx.qt(url) + "\r\n";
			HostPrintUTF8(msg);
		}
	}
	
	void addPlaylist(string url, array<dictionary> MetaDataList, bool edit = false)
	{
		if (MetaDataList.length() == 0) return;
		removeOld();
		
		int idx = find(url, "MetaDataList");
		if (idx >= 0)
		{
			if (!edit) return;
			remove(idx);
		}
		int idxJson = find(url, "json");
		if (idxJson >= 0) remove(idxJson);
		
		// Add a new record
		dictionary rec;
		rec["url"] = url;
		rec["time"] = HostGetTickCount();
		
		string sMetaDataList = jsn.dictionaryListToJson(MetaDataList);
		string gzMetaDataList = HostGzipCompress(sMetaDataList);
		rec["MetaDataList"] = gzMetaDataList;
		
		int size = gzMetaDataList.length();
		rec["size"] = size;
		totalSize += size;
		list.insertAt(0, rec);
		
		if (cfg.csl > 1)
		{
			if (sMetaDataList.length() > 0)
			{
				if (false)
				{
					int compRate = int(float(gzMetaDataList.length()) / float(sMetaDataList.length()) * 100);
					HostPrintUTF8("Compression rate (MetaDataList): " + compRate + "%");
				}
				string msg = "Cache size (MetaDataList): ";
				msg += (size / 1024) + " / " + (totalSize / 1024) + " KB";
				msg += " - " + tx.qt(url) + "\r\n";
				HostPrintUTF8(msg);
			}
		}
	}
	
	string getJson(string url, string &inout imgUrl)
	{
		int idx = find(url, "json");
		if (idx >= 0)
		{
			uint prevTime = uint(list[idx]["time"]);
			uint curTime = HostGetTickCount();
			if (curTime >= prevTime && (lifeTimeItem == 0 || curTime - prevTime < lifeTimeItem))
			{
				string gzJson = string(list[idx]["json"]);
				string json = HostDecompress(gzJson);
				imgUrl = string(list[idx]["imgUrl"]);
				return json;
			}
			else
			{
				remove(idx);
			}
		}
		return "";
	}
	
	dictionary getItem(string url, array<dictionary> &QualityList)
	{
		int idx = find(url, "MetaData");
		if (idx >= 0)
		{
			uint prevTime = int(list[idx]["time"]);
			uint curTime = HostGetTickCount();
			if (curTime >= prevTime && (lifeTimeItem == 0 || curTime - prevTime < lifeTimeItem))
			{
				string gzMetaData = string(list[idx]["MetaData"]);
				string sMetaData = HostDecompress(gzMetaData);
				dictionary MetaData = jsn.jsonToDictionary(sMetaData);
				
				if (QualityList !is null)
				{
					string gzQualityList = string(list[idx]["QualityList"]);
					string sQualityList = HostDecompress(gzQualityList);
					QualityList = jsn.jsonToDictionaryList(sQualityList);
				}
				
				return MetaData;
			}
			else
			{
				remove(idx);
			}
		}
		return {};
	}
	
	array<dictionary> getPlaylist(string url)
	{
		int idx = find(url, "MetaDataList");
		if (idx >= 0)
		{
			uint prevTime = uint(list[idx]["time"]);
			uint curTime = HostGetTickCount();
			if (curTime >= prevTime && (lifeTimePlaylist == 0 || curTime - prevTime < lifeTimePlaylist))
			{
				string gzMetaDataList = string(list[idx]["MetaDataList"]);
				string sMetaDataList = HostDecompress(gzMetaDataList);
				return jsn.jsonToDictionaryList(sMetaDataList);
			}
			else
			{
				remove(idx);
			}
		}
		return {};
	}
	
	uint getTime(string url, string key = "")
	{
		int idx = find(url, key);
		if (idx >= 0)
		{
			return uint(list[idx]["time"]);
		}
		return 0;
	}
	
}

CACHE cache;

//----------------------- END of class CACHE -------------------------



class HIST
{
	array<dictionary> list;
	
	int find(string path, bool toAlbum, uint startTime = 0, int finishMode = -1)
	{
		for (uint i = 0; i < list.length(); i++)
		{
			if (string(list[i]["path"]) == path)
			{
				if (bool(list[i]["toAlbum"]) == toAlbum)
				{
					if (startTime == 0 || uint(list[i]["startTime"]) == startTime)
					{
						if (finishMode < 0 || bool(list[i]["finish"]) == (finishMode == 1))
						{
							return i;
						}
					}
				}
			}
		}
		return -1;
	}
	
	int findPrev(string path, bool toAlbum, uint curStartTime = 0, int prevFinishMode = -1)
	{
		int idx = find(path, toAlbum, curStartTime);
		if (idx >= 0)
		{
			for (uint i = idx + 1; i < list.length(); i++)
			{
				if (string(list[i]["path"]) == path)
				{
					if (bool(list[i]["toAlbum"]) == toAlbum)
					{
						if (prevFinishMode < 0 || bool(list[i]["finish"]) == (prevFinishMode == 1))
						{
							return i;
						}
					}
				}
			}
		}
		return -1;
	}
	
	void add(string path, bool toAlbum, uint startTime, bool finish = false)
	{
		int idx = find(path, toAlbum, startTime, finish ? 1 : 0);
		if (idx >= 0) return;
		
		dictionary item;
		item.set("path", path);
		item.set("toAlbum", toAlbum);
		item.set("startTime", startTime);
		item.set("finish", finish);
		item.set("local", finish);
		item.set("cancelTime", 0);
		item.set("noSaveCache", false);
		
		int doubleTrigger = _judgeDoubleTrigger(path, toAlbum, startTime);
		item.set("doubleTrigger", doubleTrigger);
		
		list.insertAt(0, item);
	}
	
	void remove(string path, bool toAlbum, uint startTime)
	{
		int idx = find(path, toAlbum, startTime, 0);
		if (idx >= 0)
		{
			list[idx].set("finish", true);
			list[idx].set("finishTime", HostGetTickCount());
		}
		
		if (list.length() > 2)
		{
			//uint curTime = HostGetTickCount();
			for (int i = int(list.length() - 1); i >= 2; i--)
			{
				if (bool(list[i]["finish"]))
				{
					list.removeAt(i);
				}
				else
				{
					i--;	// left !finish & its next index
				}
			}
		}
	}
	
	int _judgeDoubleTrigger(string path, bool toAlbum, uint startTime)
	{
		int doubleTrigger = 0;
		if (list.length() > 0)
		{
			if (string(list[0]["path"]) == path)
			{
				if (bool(list[0]["toAlbum"]) == toAlbum)
				{
					if (int(list[0]["doubleTrigger"]) == 0)
					{
						uint prevStartTime = uint(list[0]["startTime"]);
						if (startTime >= prevStartTime)
						{
							uint diffTime = startTime - prevStartTime;
//HostPrintUTF8("diffTime: " + diffTime);
							if (diffTime < DOUBLE_TRIGGER_INTERVAL_1)
							{
								doubleTrigger = 1;
							}
							else if (diffTime < DOUBLE_TRIGGER_INTERVAL_2)
							{
								doubleTrigger = 2;
							}
							if (doubleTrigger > 0)
							{
								list[0]["doubleTrigger"] = -1;
								list[0]["noSaveCache"] = false;
							}
						}
					}
				}
			}
		}
		return doubleTrigger;
	}
	
	int getDoubleTrigger(string path, bool toAlbum, uint startTime)
	{
		int idx = find(path, toAlbum, startTime, 0);
		return int(list[idx]["doubleTrigger"]);
	}
	
	void blockSaveCache(string path, bool toAlbum, uint startTime)
	{
		int idx = find(path, toAlbum, startTime, 0);
		if (idx >= 0)
		{
			uint cancelTime = HostGetTickCount();
			
			for (uint i = idx + 1; i < list.length(); i++)
			{
				if (string(list[i]["path"]) == path)
				{
					if (bool(list[i]["toAlbum"]) == toAlbum)
					{
						if (!bool(list[i]["finish"]))
						{
							if (uint(list[i]["cancelTime"]) == 0)
							{
								list[i]["cancelTime"] = cancelTime;
							}
							if (!bool(list[i]["noSaveCache"]))
							{
								if (int(list[i]["doubleTrigger"]) == 0)
								{
									list[i]["noSaveCache"] = true;
								}
							}
						}
					}
				}
			}
		}
	}
	
	void cancelAll()
	{
		int _cacheCancelTime = cfg.getInt("NETWORK", "cache_cancel_time");	// seconds
		if (_cacheCancelTime < 0 || _cacheCancelTime > 10)
		{
			_cacheCancelTime = cfg.getInt("NETWORK", "cache_cancel_time", 1);
			cfg.setInt("NETWORK", "cache_cancel_time", _cacheCancelTime);
		}
		uint cacheCancelTime = uint(_cacheCancelTime * 1000);	// milliseconds
		uint cancelTime = HostGetTickCount();
		
		for (uint i = 0; i < list.length(); i++)
		{
			if (!bool(list[i]["finish"]))	// the processing is still working
			{
				if (uint(list[i]["cancelTime"]) == 0)
				{
					list[i]["cancelTime"] = cancelTime;
				}
				if (!bool(list[i]["noSaveCache"]))
				{
					if (int(list[i]["doubleTrigger"]) == 0)
					{
						uint startTime = uint(list[i]["startTime"]);
						if (cancelTime >= startTime)
						{
							if (cancelTime - startTime < cacheCancelTime)
							{
								list[i]["noSaveCache"] = true;
							}
						}
					}
				}
			}
		}
	}
	
	int checkCancel(string path, bool toAlbum, uint startTime, bool showMsg = true)
	{
		string inUrl = _ReviseUrl(path);
		if (showMsg) showMsg = (cfg.csl > 0);
		
		int idx = find(path, toAlbum, startTime, 0);
		if (idx >= 0)
		{
			uint cancelTime = uint(list[idx]["cancelTime"]);
			if (cancelTime > 0 && cancelTime >= startTime)
			{
				int doubleTrigger = int(list[idx]["doubleTrigger"]);
				if (showMsg && doubleTrigger >= 0)
				{
					HostPrintUTF8("[yt-dlp] Canceled - " + tx.qt(inUrl) + "\r\n");
				}
				if (bool(list[idx]["noSaveCache"]))
				{
					return 2;
				}
				return 1;
			}
		}
		return 0;
	}
	
}

HIST hist;

//---------------------- END of class HIST ------------------------



class YTDLP
{
	string exePath;
	string version;
	string tmpHash;
	uint updateCheckTime = 0;	// milliseconds
	uint UPDATE_CHECK_INTERVAL = 7200000;	// milliseconds
	
	array<string> errors = {"(OK)", "(NOT FOUND)", "(LOOKS INVALID)", "(CRITICAL ERROR!)"};
	int error = 0;
	
	int playlistForceExpand = 0;
	
	string SCHEME = "dl//";
	
	
	void getExePath()
	{
		string ytdlpLocation = cfg.getStr("MAINTENANCE", "ytdlp_location");
		if (!ytdlpLocation.empty())
		{
			if (ytdlpLocation.Right(1) != "\\") ytdlpLocation += "\\";
			exePath = ytdlpLocation + YTDLP_EXE;
		}
		else
		{
			exePath = HostGetExecuteFolder() + "Module\\" + YTDLP_EXE;
		}
	}
	
	string getBackupExePath()
	{
		string bkPath;
		if (exePath.Right(4) == ".exe")
		{
			bkPath = exePath;
			bkPath.insert(bkPath.length() - 4, ".bk");	// .exe -> .bk.exe
		}
		return bkPath;
	}
	
	void _checkFileInfo()
	{
		if (cfg.getInt("MAINTENANCE", "critical_error") != 0)
		{
			error = 3; return;
		}
		getExePath();
		if (!HostFileExist(exePath))
		{
			error = 1; return;
		}
		
		FileVersion fileInfo;
		if (!fileInfo.Open(exePath))
		{
			error = 2; return;
		}
		else
		{
			bool doubt = false;
			if (fileInfo.GetProductName() != "yt-dlp" || fileInfo.GetInternalName() != "yt-dlp")
			{
				doubt = true;
			}
			else if (fileInfo.GetOriginalFilename() != "yt-dlp.exe")
			{
				doubt = true;
			}
			else if (fileInfo.GetCompanyName() != "https://github.com/yt-dlp")
			{
				doubt = true;
			}
			/*
			// The copyright property in fileInfo was removed from yt-dlp 250907
			else if (fileInfo.GetLegalCopyright().find("UNLICENSE") < 0)
			{
				doubt = true;
			}
			*/
			else if (fileInfo.GetProductVersion().find("Python") < 0)
			{
				doubt = true;
			}
			else
			{
				version = fileInfo.GetFileVersion();	// get version
				if (version.empty())
				{
					doubt = true;
				}
			}
			
			fileInfo.Close();
			if (doubt)
			{
				error = 2; return;
			}
		}
		
		if (error > 0)
		{
			error = 0;
		}
		
		return;
	}
	
	int checkFileInfo()
	{
		_checkFileInfo();
		
		if (error > 0)
		{
			cfg.deleteKey("MAINTENANCE", "update_ytdlp");
			version = "";
		}
		return error;
	}
	
	string _fileHash(string path)
	{
		uintptr fp = HostFileOpen(path);
		string data = HostFileRead(fp, HostFileLength(fp));
		HostFileClose(fp);
		return HostHashSHA256(data);
	}
	
	void checkFileHash()
	{
		if (error == 0)
		{
			bool isNew = false;
			string exeHash = _fileHash(exePath);
			if (!tmpHash.empty())
			{
				if (tmpHash != exeHash)
				{
					isNew = true;
				}
			}
			else
			{
				string bkHash = cfg.getStr("MAINTENANCE", "ytdlp_hash");
				if (bkHash.empty() || bkHash != exeHash)
				{
					isNew = true;
				}
			}
			
			if (isNew)
			{
				string msg = "yt-dlp.exe\r\n";
				msg += "Current version: " + version;
				HostMessageBox(msg, "[yt-dlp] INFO: New yt-dlp", 2, 0);
			}
			
			tmpHash = exeHash;
		}
	}
	
	void criticalError()
	{
		version = "";
		error = 3;
		cfg.setInt("MAINTENANCE", "critical_error", 1, false);
		cfg.deleteKey("MAINTENANCE", "update_ytdlp");
		string msg = "\"yt-dlp.exe\" did not work as expected.\r\n";
		//HostPrintUTF8("\r\n[yt-dlp] CRITICAL ERROR! " + msg);
		msg += "If there are no problems, set [critical_error] to 0 in the config file and reload the script.";
		HostMessageBox(msg, "[yt-dlp] CRITICAL ERROR", 3, 2);
	}
	
	bool _fileCopy(string srcPath, string dstPath)
	{
		// Hidden files are not supported.
		string cmd = "cmd.exe";
		string para = "/c copy /y /b /v";
		para += " " + tx.qt("\\\\?\\" + srcPath);
		para += " " + tx.qt("\\\\?\\" + dstPath);
		string ret = HostExecuteProgram(cmd, para);
//HostPrintUTF8("File Copy: " + ret);
		if (ret.find("1 file(s) copied") >= 0)
		{
			return true;
		}
		return false;
	}
	
	bool backupExe()
	{
		bool backup = false;
		
		string exeHash = _fileHash(exePath);
		string bkPath = getBackupExePath();
		if (HostFileExist(bkPath))
		{
			if (_fileHash(bkPath) != exeHash)
			{
				backup = true;
			}
		}
		else
		{
			backup = true;
		}
		
		if (backup)
		{
			if (!_fileCopy(exePath, bkPath))
			{
				backup = false;
			}
		}
		
		return backup;
	}
	
	bool restoreExe()
	{
		bool restore = false;
		
		string bkPath = getBackupExePath();
		if (HostFileExist(bkPath))
		{
			string bkHash = _fileHash(bkPath);
			if (bkHash != _fileHash(exePath))
			{
				if (bkHash == cfg.getStr("MAINTENANCE", "ytdlp_hash"))
				{
					restore = true;
				}
			}
		}
		
		if (restore)
		{
			if (!_fileCopy(bkPath, exePath))
			{
				restore = false;
			}
		}
		
		return restore;
	}
	
	void updateVersion()
	{
		cfg.setInt("MAINTENANCE", "update_ytdlp", 0);
		
		if (checkFileInfo() > 0) return;
		if (tmpHash.empty() || tmpHash != cfg.getStr("MAINTENANCE", "ytdlp_hash"))
		{
			string msg = "Please make sure the current version works properly, and then try updating again.";
			HostMessageBox(msg, "[yt-dlp] INFO: Update yt-dlp.exe", 2, 1);
			return;
		}
		
		HostIncTimeOut(30000);
		string output = HostExecuteProgram(tx.qt(exePath), " -U");
		
		if (output.find("Latest version:") < 0 && output.find("ERROR:") < 0)
		{
			string msg = "No update info.";
			HostPrintUTF8("[yt-dlp] CRITICAL ERROR! " + msg + "\r\n");
			HostMessageBox(msg, "[yt-dlp] CRITICAL ERROR: Update", 3, 1);
			criticalError();
			return;
		}
		
		int pos = output.findLastNotOf("\r\n");
		output = output.Left(pos + 1);
		if (output.find("ERROR:") >= 0)
		{
			output += "\r\n\r\n";
			output += "If the folder is not writable, you can change the [ytdlp_location] setting.";
		}
		HostMessageBox(output, "[yt-dlp] INFO: Update yt-dlp.exe", 2, 1);
		
		if (checkFileInfo() > 0)
		{
			restoreExe();
			if (checkFileInfo() > 0)
			{
				string msg =
					"Automatic update seems to have failed.\r\n"
					"Please replace \"yt-dlp.exe\" with a working version manually.\r\n";
				msg += "\r\n" + exePath;
				HostMessageBox(msg, "[yt-dlp] ALERT: Auto Update", 0, 0);
			}
		}
		else
		{
			tmpHash = _fileHash(exePath);
		}
	}
	
	int _checkLogUpdate(string log)
	{
		if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 1)
		{
			int pos1 = tx.findRegExp(log, "\\n\\[debug\\] Downloading yt-dlp\\.exe ");
			if (pos1 >= 0)
			{
				int pos2 = tx.findRegExp(log, "(?i)\\nERROR: Unable to write to[^\r\n]+yt-dlp\\.exe", pos1 + 1);
				if (pos2 >= 0)
				{
					cfg.setInt("MAINTENANCE", "update_ytdlp", 0);
					
					if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Auto update failed.\r\n");
					string msg =
						"The automatic update failed.\r\n"
						"\r\n"
						"Unable to overwrite:\r\n";
					msg += exePath + "\r\n"
						"\r\n"
						"You can change the [ytdlp_location] setting to a location with write permission.\r\n"
						"\r\n"
						"The [update_ytdlp] setting has been reset.";
					HostMessageBox(msg, "[yt-dlp] ALERT: Auto Update", 0, 0);
					return -1;
				}
				
				if (checkFileInfo() > 0)
				{
					cfg.setInt("MAINTENANCE", "update_ytdlp", 0);
					
					if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Auto update failed.\r\n");
					
					restoreExe();
					
					string msg =
						"Automatic update seems to have failed.\r\n"
						"\r\n"
						"The [update_ytdlp] setting has been reset.\r\n";
					
					if (checkFileInfo() > 0)	// fialed to restore
					{
						msg += "Please replace \"yt-dlp.exe\" with a working version manually.";
						HostMessageBox(msg, "[yt-dlp] ERROR: Auto Update", 0, 0);
						return -2;
					}
					else
					{
						msg += "Set [update_ytdlp] back to 1 to retry, or try setting it to 2.";
						HostMessageBox(msg, "[yt-dlp] ERROR: Auto Update", 0, 0);
						return -1;
					}
				}
				
				int pos3 = tx.findRegExp(log, "\\nUpdated yt-dlp to", pos1 + 1);
				if (pos3 >= 0)
				{
					tmpHash = _fileHash(exePath);
					
					if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Auto update successful.\r\n");
					string msg = tx.getLine(log, pos3 + 1);
					HostMessageBox(msg, "[yt-dlp] INFO: Auto Update", 2, 0);
				}
				return 1;
			}
		}
		return 0;
	}
	
	bool _checkLogCommand(string log)
	{
		string words = "\nyt-dlp.exe: error: ";
		int pos = tx.findI(log, words);
		if (pos >= 0)
		{
			pos += words.length();
			string msg = tx.getLine(log, pos);
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] ERROR! " + msg + "\r\n");
			HostMessageBox(msg, "[yt-dlp] ERROR: Cpmmand", 0, 0);
			return true;
		}
		if (tx.findI(log, "[debug] Command-line config:") < 0)
		{
			string msg = "No command line info.";
			HostPrintUTF8("[yt-dlp] CRITICAL ERROR! " + msg + "\r\n");
			HostMessageBox(msg, "[yt-dlp] CRITICAL ERROR: Cpmmand", 3, 1);
			criticalError();
			return true;
		}
		return false;
	}
	
	bool _checkLogVersion(string log, string tmpVersion)
	{
		if (tmpVersion.empty()) return true;
		
		int pos = log.find("\n[debug] yt-dlp version");
		if (pos >= 0)
		{
			pos += 1;
			string line = tx.getLine(log, pos);
			if (line.find(tmpVersion) >= 0)
			{
				return false;
			}
		}
		string msg = "Incorrect yt-dlp version.";
		HostPrintUTF8("[yt-dlp] CRITICAL ERROR! " + msg + "\r\n");
		HostMessageBox(msg, "[yt-dlp] CRITICAL ERROR: Version", 3, 1);
		criticalError();
		return true;
	}
	
	bool _checkLogBrowser(string log)
	{
		bool check = false;
		if (tx.findRegExp(log, "(?i)\\nERROR: Could not [^\r\n]+? cookies? database") >= 0) check = true;
		if (tx.findRegExp(log, "(?i)\\nERROR: Failed to decrypt with DPAPI") >= 0) check = true;
		if (check)
		{
			string msg = "Check your [cookie_browser] setting.";
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] ERROR! " + msg + "\r\n");
			msg += "\r\nIt will be commented out.";
			HostMessageBox(msg, "[yt-dlp] ERROR: Cookie Browser", 0, 0);
			
			cfg.cmtoutKey("COOKIE", "cookie_browser");
		}
		return check;
	}
	
	bool _checkLogLanguageCode(string log)
	{
		int pos1 = tx.findRegExp(log, "(?i)\nERROR: \\[youtube\\] [^\r\n]*(Unsupported language code:)");
		if (pos1 >= 0)
		{
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] ERROR! Your language code [base_lang] is not supported for the menu label on YouTube.\r\n");
			int pos2 = tx.findEol(log, pos1);
			string msg = log.substr(pos1, pos2 - pos1);
			int pos = tx.findRegExp(msg, ". Supported language codes");
			if (pos >= 0)
			{
				msg = msg.Left(pos) + "\r\n\r\n" + msg.substr(pos + 2);
			}
			if (cfg.getStr("YOUTUBE", "base_lang").empty())
			{
				cfg.setStr("YOUTUBE", "base_lang", "en");
				msg += "\r\n\r\nThe following setting is now set to \"en\".";
			}
			else
			{
				cfg.cmtoutKey("YOUTUBE", "base_lang");
				msg += "\r\n\r\nChage the following setting:";
			}
			msg += "\r\nConfig File > [YOUTUBE] > base_lang";
			HostMessageBox(msg, "[yt-dlp] ERROR: Language Code", 0, 0);
			return true;
		}
		return false;
	}
	
	bool _checkLogJsRuntime(string log, string url)
	{
		if (tx.findRegExp(log, "(?i)WARNING: \\[youtube\\] [^\r\n]*challenge solving failed") >= 0)
		{
			if (tx.findRegExp(log, "(?i)JS runtimes: none") >= 0)
			{
				string msg = "Please use a JS runtime such as \"Deno.exe\".";
				if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] " + msg + " - " + tx.qt(url) + "\r\n");
				HostMessageBox(msg + "\r\n" + url, "[yt-dlp] INFO: JS Runtime", 2, 1);
				return true;
			}
		}
		return false;
	}
	
	bool _checkLogLiveFromStart(string log)
	{
		if (tx.findRegExp(log, "(?i)\\nERROR: ?\\[twitch:stream\\][^\r\n]*--live-from-start") >= 0)
		{
			return true;
		}
		return false;
	}
	
	bool _checkLogLiveOffline(string log, string url)
	{
		if (tx.findRegExp(log, "(?i)\\nERROR: [^\r\n]* (not currently live|off ?line|livestream has ended)") >= 0)
		{
			string msg = "This channel is not live now.";
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] " + msg + " - " + tx.qt(url) + "\r\n");
			HostMessageBox(msg + "\r\n" + url, "[yt-dlp] INFO: No Live", 2, 1);
			return true;
		}
		return false;
	}
	
	bool _checkLogServerBlock(string log, string url)
	{
		int pos = tx.findRegExp(log, "(?i)\\nERROR: [^\r\n]* wait and try later");
		if (pos >= 0)
		{
			string msg = tx.getLine(log, pos + 1);
			msg = msg.substr(7);
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] " + msg + " - " + tx.qt(url) + "\r\n");
			HostMessageBox(msg + "\r\n" + url, "[yt-dlp] INFO: Server", 2, 1);
			return true;
		}
		return false;
	}
	
	bool _checkLogGeoRestriction(string log, string url)
	{
		if (tx.findRegExp(log, "(?i)Error: [^\r\n]* not available [^\r\n]+ geo restriction") >= 0)
		{
			string msg = "This content is not available from your location due to geo restriction.";
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] " + msg + " - " + tx.qt(url) + "\r\n");
			HostMessageBox(msg + "\r\n" + url, "[yt-dlp] INFO: Geo Restriction", 2, 1);
			return true;
		}
		return false;
	}
	
	bool _checkLogRegisteredOnly(string log, string url)
	{
		if (tx.findRegExp(log, "(?i)\\nERROR: [^\r\n]*only available[^\r\n]+registered") >= 0)
		{
			string msg = "This content is available to registered users only.";
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] " + msg + " - " + tx.qt(url) + "\r\n");
			msg += "\r\nPlease log in to your account and use the cookie option.\r\n";
			HostMessageBox(msg + "\r\n" + url, "[yt-dlp] INFO: Need Login", 2, 1);
			return true;
		}
		return false;
	}
	
	int _checkLogForbidden(string log, string url, string &inout referer)
	{
		// Server error 403 or 404
		int pos = tx.findRegExp(log, "(?i)\\nERROR: [^\r\n]*HTTP Error 40[34]");
		if (pos >= 0)
		{
			if (referer.empty())
			{
				string line = tx.getLine(log, pos + 1);
				if (tx.findI(line, "Cloudflare anti-bot") >= 0)
				{
					return -2;
				}
				else
				{
					referer = cfg.getStr("NETWORK", "referer");
					if (!referer.empty())
					{
						if (referer.find("http") == 0)
						{
							return -1;
						}
						referer = "";
						cfg.cmtoutKey("NETWORK", "referer");
					}
				}
			}
			string msg = "Access forbidden or not found.";
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] " + msg + " - " + tx.qt(url) + "\r\n");
			//msg += "\r\nIf you have a valid referer, set the referer option in the [NETWORK] section and try again.\r\n";
			HostMessageBox(msg + "\r\n" + url, "[yt-dlp] INFO: Access Forbidden", 2, 1);
			return 1;
		}
		return 0;
	}
	
	void _printNoEntries(string log, string url)
	{
		if (cfg.csl > 0)
		{
			string msg;
			if (log.find("ERROR") >= 0)
			{
				HostPrintUTF8("[yt-dlp] Unsupported - " + tx.qt(url) + "\r\n");
			}
			else if (tx.findI(log, "downloading 0 items") >= 0)
			{
				msg = "No entries in this playlist.";
				HostPrintUTF8("[yt-dlp] " + msg + " - " + tx.qt(url) + "\r\n");
			}
			else
			{
				msg = "No data or info.";
				HostPrintUTF8("[yt-dlp] ERROR! " + msg + " - " + tx.qt(url) + "\r\n");
			}
		}
	}
	
	string _getErrorLines(string log)
	{
		string outStr = "";
		_removeMetadata(log);
		int pos1 = 0;
		int pos0;
		string log0;
		do {
			pos0 = pos1;
			pos1 = tx.findRegExp(log, "(?i)ERROR", pos1);
			if (pos1 >= 0)
			{
				string line = tx.getLine(log, pos1);
				if (tx.findI(line, "[debug]") != 0)
				{
					if (tx.findI(line, "  File \"") != 0)
					{
						if (line.find("WARNING:") != 0)
						{
							outStr += line + "\r\n";
						}
					}
				}
				pos1 = log.find("\n", pos1);
				//pos1 = tx.findNextLineTop(log, pos1);
			}
		} while (pos1 > pos0);
		
		return outStr;
	}
	
	array<string> _getErrorIds(string log)
	{
		array<string> errIds = {};
		_removeMetadata(log);
		
		int pos1 = 0;
		int pos0;
		do {
			pos0 = pos1;
			string id;
			pos1 = tx.findRegExp(log, "(?i)(?:^|\\n)ERROR: \\[[^\\]]+\\] ([-\\w@]+): ", id, pos1);
			if (pos1 >= 0)
			{
				errIds.insertLast(id);
				pos1 = log.find("\n", pos1);
				//pos1 = tx.findNextLineTop(log, pos1);
			}
		} while (pos1 > pos0);
		
		return errIds;
	}
	
	bool _removeMetadata(string &inout log)
	{
		// Remove the metadata area that cannot be used for judgment.
		string reg = "(?i)(\\n\\[debug\\] ffmpeg command line:.+?)\\n(?:\\[|error:|warning:)";
		string _s;
		int pos = tx.findRegExp(log, reg, _s);
		if (pos >= 0)
		{
			log.erase(pos, _s.length());
			return true;
		}
		return false;
	}
	
	array<string> _getJsonList(string data, uint &out logPos)
	{
		array<string> jsonList = {};
		logPos = 0;
		
		int pos1;
		if (data.Left(1) == "{")
		{
			pos1 = 0;
		}
		else
		{
			pos1 = data.find("\n{", 0);
			if (pos1 >= 0) pos1 += 1;
		}
		
		if (pos1 >= 0)
		{
			int pos0;
			do {
				pos0 = pos1;
				int pos2 = data.find("}\n", pos1);
				if (pos2 < 0) break;
				pos2 += 1;
				string json = data.substr(pos1, pos2 - pos1);
				jsonList.insertLast(json);
				logPos = pos2 + 1;
				pos1 = data.find("\n{", pos2);
				if (pos1 < 0) break;
				pos1 += 1;
			} while (pos1 > pos0);
		}
		
		return jsonList;
	}
	
	array<string> _getJsonList(string data)
	{
		uint logPos;
		return _getJsonList(data, logPos);
	}
	
	array<string> _getJsonList2(string data, uint &out logPos)
	{
		// Too slow to handle a large playlist
		
		array<string> jsonList;
		logPos = 0;
		data = "\n" + data;
		
		int pos1 = 0;
		int pos0;
		do {
			pos0 = pos1;
			
			pos1 = data.find("\n{", pos1);
			if (pos1 >= 0)
			{
				pos1 += 1;
				string json = tx.getLine(data, pos1);
				if (json.Right(1) == "}")
				{
					jsonList.insertLast(json);
					logPos = pos1 + json.length();
				}
			}
		} while (pos1 > pos0);
		
		return jsonList;
	}
	
	array<string> exec1(string url, int playlistMode, string retry = "")
	{
		if (checkFileInfo() > 0) return {};
		checkFileHash();
		string tmpVersion = version;
		
		if (cfg.csl > 0)
		{
			string msg = "\r\n[yt-dlp] ";
			if (playlistMode == 0)
			{
				msg += "Parsing";
			}
			else
			{
				msg += "Extracting entries";
			}
			if (retry.find("http") == 0)
			{
				msg += " (Retry wtih referer)";
			}
			else if (!retry.empty())
			{
				msg += " (Retry " + retry + ")";
			}
			msg += "... - " + tx.qt(url) + "\r\n";
			HostPrintUTF8(msg);
		}
		
		bool isYoutube = _IsUrlSite(url, "youtube");
		
		string options = "";
		
		if (playlistMode == 0)
		{
			// a single video/audio
			// called from PlayitemParse
			
			if (isYoutube)
			{
				options += " -I 1";
			}
			else
			{
				options += " -I -1";	// get playlist_count
			}
			
			if (_IsPotentialBiliPart(url))
			{
				options += " --yes-playlist";
			}
			else
			{
				options += " --no-playlist";
			}
			
		}
		else
		{
			// playlist
			// called from PlaylistParse
			
			if (_IsPotentialBiliPart(url))
			{
				options += " --yes-playlist";
			}
			else if (playlistMode == 2)
			{
				options += " --yes-playlist";
			}
			else
			{
				options += " --no-playlist";
			}
			
			options += " --flat-playlist";
			// Fastest and reliable for collecting urls from a playlist.
			// But collected items have no title or thumbnail except for some websites like youtube.
			// Missing properties (title/thumbnail/duration) are fetched by a subsequent function "_getMetadata".
		}
		
		bool hasCookie = _addOptionsCookie(options);
		
		if (isYoutube)
		{
			string youtubeArgs = _getYoutubeArgs(hasCookie);
			options += " --extractor-args " + tx.qt(youtubeArgs);
			
			string sb = cfg.getStr("YOUTUBE", "sponsor_block");
			if (!sb.empty())
			{
				options += " --sponsorblock-mark " + tx.qt(sb);
			}
		}
		
		options += " --all-subs";
		
		if (retry != "twich live")
		{
			if (_IsUrlSite(url, "twitch.tv"))	// for twitch
			{
				if (cfg.getInt("FORMAT", "twitch_live_vod") == 1)
				{
					options += " --live-from-start";
				}
			}
			/*
			else if (isYoutube)
			{
				if (cfg.getInt("YOUTUBE", "youtube_live") == 2)
				{
					// doesn't work
					options += " --live-from-start";
				}
			}
			*/
		}
		
		//options += " -R 3";	// default; 10
		options += " --encoding \"utf8\"";	// prevent garbled text
		
		_addOptionsNetwork(options);
		if (retry == "with impersonation")
		{
			string impersonate = cfg.getStr("NETWORK", "impersonate");
			impersonate.replace(" ", "");
			options += " --extractor-args " + tx.qt("generic:impersonate=" + impersonate);
		}
		else if (retry.find("http") == 0)	// referer
		{
			options += " --add-headers " + tx.qt("Referer: " + retry);
		}
		
		string proxy = cfg.getStr("NETWORK", "proxy");
		
		if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 1)
		{
			if (!tmpHash.empty() && tmpHash == cfg.getStr("MAINTENANCE", "ytdlp_hash"))
			{
				uint curTime = HostGetTickCount();
				if (updateCheckTime == 0 || curTime - updateCheckTime >= UPDATE_CHECK_INTERVAL)
				{
					options += " -U";
					updateCheckTime = curTime;
				}
			}
		}
		
		options += " -j";	// "-j" must be in lower case
		
		// Execute
		string output;
		if (playlistMode == 0)
		{
			options += " -v";
			options += " -- " + url;
			HostIncTimeOut(60000);
			output = HostExecuteProgram(tx.qt(exePath), options);
		}
		else
		{
			output = _extractPlaylist(url, options);
		}
		//output = _reviseLog(output);
		
		uint logPos = 0;
		array<string> jsonList = _getJsonList(output, logPos);
		string log = output.substr(logPos).TrimLeft("\r\n");
		
		if (cfg.csl == 1)
		{
			HostPrintUTF8(_getErrorLines(log));
		}
		else if (cfg.csl == 2)
		{
			HostPrintUTF8(log);
		}
		else if (cfg.csl == 3)
		{
			string json = output.Left(logPos);
			uint maxLen = 1000000;
			if (false && json.length() > maxLen)
			{
				json = json.Left(maxLen);
				json += "...\r\n(-------- omitted --------)\r\n\r\n";
				HostPrintUTF8(json + log);
			}
			else
			{
				HostPrintUTF8(output);
			}
		}
		
		if (_checkLogCommand(log)) return {};
		
		int update = _checkLogUpdate(log);
		if (update == 1)	// succeeded
		{
			// Restart using the new yt-dlp automatically
		}
		else if (update == -2)
		{
			return {};
		}
		else if (update == 0)
		{
			if (_checkLogVersion(log, tmpVersion)) return {};
		}
		
		if (jsonList.length() == 0)
		{
			if (_checkLogBrowser(log)) return {};
			if (_checkLogLanguageCode(log)) return {};
			if (_checkLogJsRuntime(log, url)) return {};
			
			if (_checkLogLiveFromStart(log))
			{
				if (retry.empty())
				{
					if (options.find(" --live-from-start") >= 0)
					{
						// Retry without --live-from-start
						return exec1(url, playlistMode, "twich live");
					}
				}
			}
			if (_checkLogLiveOffline(log, url)) return {};
			
			if (_checkLogServerBlock(log, url)) return {};
			if (_checkLogGeoRestriction(log, url)) return {};
			if (_checkLogRegisteredOnly(log, url)) return {};
			int forbidden = _checkLogForbidden(log, url, retry);
			if (forbidden != 0)
			{
				if (forbidden == -1 && retry.find("http") == 0)
				{
					// Retry with referer(=retry)
					return exec1(url, playlistMode, retry);
				}
				else if (forbidden == -2)
				{
					return exec1(url, playlistMode, "with impersonation");
				}
				return {};
			}
			
			_printNoEntries(log, url);
		}
		
		return jsonList;
	}
	
	
	array<string> exec2(array<string> urls, int opItem, bool opFlat = false, array<string> &errIds = {}, string headMsg = "")
	{
		if (urls.length() == 0) return {};
		
		if (cfg.csl > 0)
		{
			string msg;
			msg += "\r\n[yt-dlp] ";
			if (headMsg.empty())
			{
				if (opItem == 0)
				{
					headMsg = "Extracting nested playlist entries";
				}
				else
				{
					headMsg = "Collecting metadata";
				}
			}
			msg += headMsg + "... - ";
			if (urls.length() > 1)
			{
				msg += urls.length() + " URLs starting with ";
			}
			msg += tx.qt(urls[0]);
			msg += "\r\n";
			HostPrintUTF8(msg);
		}
		
		string options = "";
		
		if (opItem == 1)
		{
			options += " -I 1";
		}
		else if (opItem == -1)
		{
			options += " -I -1";	// get playlist_count
		}
		
		if (opFlat)
		{
			// for responsive websites like youtube
			options += " --flat-playlist";
		}
		
		if (_IsPotentialBiliPart(urls[0]))
		{
			options += " --yes-playlist";
		}
		else
		{
			options += " --no-playlist";
		}
		
		//options += " -R 3";	// default; 10
		options += " --encoding \"utf8\"";	// prevent garbled text
		
		_addOptionsNetwork(options);
		
		bool hasCookie = _addOptionsCookie(options);
		
		if (_IsUrlSite(urls[0], "youtube"))
		{
			string youtubeArgs = _getYoutubeArgs(hasCookie);
			options += " --extractor-args " + tx.qt(youtubeArgs);
			
			//options += " --no-js-runtimes";	// Don't use Deno
		}
		
		options += " -j";	// "-j" must be in lower case
		
		// Execute
		string output;
		if (opItem == 0)
		{
			output = _extractPlaylist2(urls, options);
		}
		else
		{
			output = _getMetadata(urls, options, opFlat);
		}
		//output = _reviseLog(output);
		
		uint logPos = 0;
		array<string> jsonList = _getJsonList(output, logPos);
		string log = output.substr(logPos).TrimLeft("\r\n");
		errIds = _getErrorIds(log);
		
		if (cfg.csl == 1)
		{
			HostPrintUTF8(_getErrorLines(log));
		}
		else if (cfg.csl == 2)
		{
			HostPrintUTF8(log);
		}
		else if (cfg.csl == 3)
		{
			HostPrintUTF8(output);
		}
		
		return jsonList;
	}
	
	
	bool _addOptionsCookie(string &inout options)
	{
		bool hasCookie = false;
		string cookieFile = cfg.getStr("COOKIE", "cookie_file");
		if (!cookieFile.empty())
		{
			options += " --cookies " + tx.qt(cookieFile);
			hasCookie = true;
		}
		else
		{
			string cookieBrowser = cfg.getStr("COOKIE", "cookie_browser");
			if (!cookieBrowser.empty())
			{
				options += " --cookies-from-browser " + tx.qt(cookieBrowser);
				hasCookie = true;
			}
		}
		
		if (hasCookie)
		{
			if (cfg.getInt("COOKIE", "mark_watched") == 1)
			{
				options += " --mark-watched";
			}
			
			string bgutilHttp = cfg.getStr("YOUTUBE", "potoken_bgutil_http");
			bgutilHttp.replace(" ", "");
			if (!bgutilHttp.empty())
			{
				options += " --extractor-args " + tx.qt("youtubepot-bgutilhttp:" + bgutilHttp);
			}
			string bgutilScript = cfg.getStr("YOUTUBE", "potoken_bgutil_script");
			bgutilScript.replace(" ", "");
			if (!bgutilScript.empty())
			{
				options += " --extractor-args " + tx.qt("youtubepot-bgutilscript:" + bgutilScript);
			}
		}
		
		return hasCookie;
	}
	
	string _getYoutubeArgs(bool hasCookie)
	{
		string youtubeArgs = "youtube:";
		youtubeArgs += "lang=" + cfg.baseLang;
		
		string playerClient = cfg.getStr("YOUTUBE", "player_client");
		playerClient.replace(" ", "");
		youtubeArgs += ";player_client=" + playerClient;
		
		if (hasCookie)
		{
			string poToken = cfg.getStr("YOUTUBE", "po_token");
			poToken.replace(" ", "");
			if (!poToken.empty())
			{
				youtubeArgs += ";po_token=" + poToken;
			}
		}
		
		return youtubeArgs;
	}
	
	void _addOptionsNetwork(string &inout options)
	{
		options += " --retry-sleep exp=1:10";
		
		string proxy = cfg.getStr("NETWORK", "proxy");
		if (!proxy.empty()) options += " --proxy " + tx.qt(proxy);
		
		int socketTimeout = cfg.getInt("FORMAT", "socket_timeout");
		if (socketTimeout > 0) options += " --socket-timeout " + socketTimeout;
		
		string sourceAddress = cfg.getStr("NETWORK", "source_address");
		if (!sourceAddress.empty()) options += " --source-address " + tx.qt(sourceAddress);
		
		string geoProxy = cfg.getStr("NETWORK", "geo_verification_proxy");
		if (!geoProxy.empty()) options += " --geo-verification-proxy " + tx.qt(geoProxy);
		
		string xff = cfg.getStr("NETWORK", "xff");
		if (!xff.empty()) options += " --xff " + tx.qt(xff);
		
		int ipv = cfg.getInt("NETWORK", "ip_version");
		if (ipv == 4) options += " -4";
		else if (ipv == 6) options += " -6";
		
		if (cfg.getInt("NETWORK", "no_check_certificates") == 1)
		{
			options += " --no-check-certificates";
		}
	}
	
	string _reviseLog(string &in log)
	{
		int pos = 0;
		while (pos >= 0)
		{
			pos = tx.findRegExp(log, "\\n\\[download\\] Downloading item \\d+ of \\d+", pos);
			if (pos < 0) break;
			tx.eraseLine(log, pos + 1);
		}
		return log;
	}
	
	void _eraseYoutubeTabError(string &inout log)
	{
		int pos = 0;
		while (pos >= 0)
		{
			pos = tx.findRegExp(log, "\\nERROR: \\[youtube:tab\\] [^\r\n]+ does not have a [^\r\n]+ tab", pos);
			if (pos < 0) break;
			tx.eraseLine(log, pos + 1);
		}
	}
	
	uint _countJson(string &inout data, bool eraseMsg)
	{
		uint cnt = 0;
		int pos1 = 0;
		int pos2 = 0;
		
		if (data.Left(1) != "{")
		{
			pos1 = data.find("\n{", pos2);
		}
		
		while (pos1 >= 0)
		{
			if (eraseMsg && pos1 > pos2)
			{
				data.erase(pos2, pos1 - pos2);
				pos1 = pos2;
			}
			pos2 = data.find("}\n", pos1);
			if (pos2 < 0) break;
			pos2 += 1;
			cnt++;
			
			pos1 = data.find("\n{", pos2);
			if (pos1 < 0) break;
		}
		
		if (eraseMsg && pos1 < 0)
		{
			data = data.Left(pos2);
		}
		
		return cnt;
	}
	
	uint _countJson2(string &inout data, bool eraseMsg)
	{
		// Too slow to handle a large playlist
		
		uint cnt = 0;
		int pos = 0;
		do {
			string c = data.substr(pos, 1);
			if (c == "{")
			{
				cnt++;
				pos = tx.findNextLineTop(data, pos);
			}
			else if (eraseMsg)
			{
				tx.eraseLine(data, pos);
			}
			else
			{
				pos = tx.findNextLineTop(data, pos);
			}
		} while (pos >= 0 && pos < int(data.length()));
		return cnt;
	}
	
	int _findJsonEnd(string data)
	{
		int pos1 = -1;
		int pos0;
		do {
			pos0 = pos1;
			pos1 = data.findLast("}}\n", pos1);
			if (pos1 >= 0)
			{
				int pos2 = tx.findLineTop(data, pos1);
				if (data.substr(pos2, 1) == "{")
				{
					return pos1 + 3;
				}
				pos1 = tx.findLineTop(data, pos1);
			}
		} while (pos1 > pos0);
		return 0;
	}
	
	string _extractPlaylist(string url, string options)
	{
		if (url.empty()) return "";
		string output;
		int PlaylistItemsTimeout = cfg.getInt("TARGET", "playlist_items_timeout");
		if (PlaylistItemsTimeout < 0)
		{
			cfg.setInt("TARGET", "playlist_items_timeout", 0);
			PlaylistItemsTimeout = 0;
		}
		uint waitTime = uint(PlaylistItemsTimeout);
		
		if (waitTime == 0)
		{
			HostIncTimeOut(2000000);
			uint startTime = HostGetTickCount();
			output = HostExecuteProgram(tx.qt(exePath), " -v" + options + " -- " + url);
			
			if (cfg.csl > 0)
			{
				uint cnt = _countJson(output, false);
				uint elapsedTime = (HostGetTickCount() - startTime)/1000;
				string msg;
				msg = "  Count: " + cnt;
				msg += "\t\tTime: " + elapsedTime + " sec";
				HostPrintUTF8(msg);
				if (cnt > 0) msg = "  Complete.\r\n";
				else msg = "  Failed to get.\r\n";
				HostPrintUTF8(msg);
			}
		}
		else	// waitTime > 0
		{
			// for devided downloads
			bool youtubeChannelTop = false;
			string joinedUrls = _ChangeUrlYoutubeChannelTop(url);
			if (!joinedUrls.empty())
			{
				youtubeChannelTop = true;
				url = joinedUrls;
			}
			
			if (cfg.csl > 0)
			{
				string msg = "  playlist_items_timeout: " + waitTime + " sec";
				HostPrintUTF8(msg);
			}
			
			uint unitIdx = 200;
			uint cnt = 0;
			int complete = 0;
			uint startTime = HostGetTickCount();
			for (uint i = 1; i <= 10000; i += unitIdx)
			{
				if (i > 600) unitIdx = 400;
				HostIncTimeOut(300000);
				string wholeOption = " -I " + i + ":" + (i + unitIdx - 1);
				if (i == 1) wholeOption += " -v";
				wholeOption += options + " -- " + url;
				string addOutput = HostExecuteProgram(tx.qt(exePath), wholeOption);
				uint addCnt = _countJson(addOutput, (i > 1));
				if (youtubeChannelTop) _eraseYoutubeTabError(addOutput);
				output.insert(_findJsonEnd(output), addOutput);
				cnt += addCnt;
				if (addCnt > 0)
				{
					uint elapsedTime = (HostGetTickCount() - startTime)/1000;
					if (cfg.csl > 0)
					{
						string msg = "  Count: " + cnt;
						msg += "\t\tTime: " + elapsedTime + " sec";
						HostPrintUTF8(msg);
					}
					if (addCnt < unitIdx/2)
					{
						complete = 1;
						break;
					}
					if (elapsedTime >= waitTime)
					{
						break;
					}
				}
				else
				{
					complete = (cnt > 0) ? 1 : -1;
					break;
				}
			}
			if (cfg.csl > 0)
			{
				string msg;
				if (complete > 0) msg = "  Complete.\r\n";
				else if (complete < 0) msg = "  Failed to get.\r\n";
				else msg = "  Time out.\r\n";
				HostPrintUTF8(msg);
			}
		}
		output.replace("\r\n{", "{");
		return output;
	}
	
	string _extractPlaylist2(array<string> urls, string options)
	{
		if (urls.length() == 0) return "";
		string output;
		string joinedUrls = "";
		for (uint i = 0; i < urls.length(); i++) joinedUrls += " " + urls[i];
		
		uint waitTime = uint(cfg.getInt("TARGET", "playlist_items_timeout"));
		if (waitTime == 0)
		{
			HostIncTimeOut(2000000);
			uint startTime = HostGetTickCount();
			output = HostExecuteProgram(tx.qt(exePath), options + " --" + joinedUrls);
			
			if (cfg.csl > 0)
			{
				uint cnt = _countJson(output, false);
				uint elapsedTime = (HostGetTickCount() - startTime)/1000;
				string msg;
				{
					msg += "  Count: " + cnt;
					msg += "\t\tTime: " + elapsedTime + " sec";
					msg += "\r\n";
					msg += (cnt == 0) ? "  Failed to get." : "  Complete.";
					msg += "\r\n";
				}
				HostPrintUTF8(msg);
			}
		}
		else	// waitTime > 0
		{
			if (cfg.csl > 0)
			{
				string msg = "  playlist_items_timeout: " + waitTime + " sec";
				HostPrintUTF8(msg);
			}
			uint unitIdx = 200;
			uint cnt = 0;
			bool timeout = false;
			uint startTime = HostGetTickCount();
			for (uint i = 1; i <= 10000 + unitIdx; i += unitIdx)
			{
				if (i > 600) unitIdx = 400;
				HostIncTimeOut(300000);
				options += " -I " + i + ":" + (i + unitIdx - 1);
				string addOutput = HostExecuteProgram(tx.qt(exePath), options + " --" + joinedUrls);
				uint addCnt = _countJson(addOutput, false);
				uint elapsedTime = (HostGetTickCount() - startTime)/1000;
				if (addCnt > 0)
				{
					output += addOutput;
					cnt += addCnt;
					if (cfg.csl > 0)
					{
						string msg = "  Count: " + cnt;
						msg += "\t\tTime: " + elapsedTime + " sec";
						HostPrintUTF8(msg);
					}
				}
				if (addCnt < unitIdx) break;
				if (elapsedTime >= waitTime)
				{
					timeout = true;
					break;
				}
			}
			if (cfg.csl > 0)
			{
				string msg;
				if (timeout) msg = "  Time out.\r\n";
				else if (cnt == 0) msg = "  Failed to get.\r\n";
				else msg = "  Complete.\r\n";
				HostPrintUTF8(msg);
			}
		}
		output.replace("\r\n{", "{");
		return output;
	}
	
	string _getMetadata(array<string> urls, string options, bool isResponsive)
	{
		if (urls.length() == 0) return "";
		string output;
		
		uint waitTime;
		if (isResponsive)
		{
			waitTime = uint(cfg.getInt("TARGET", "playlist_items_timeout"));
		}
		else
		{
			int PlaylistMetadataTimeout = cfg.getInt("TARGET", "playlist_metadata_timeout");
			if (PlaylistMetadataTimeout < 0)
			{
				cfg.setInt("TARGET", "playlist_metadata_timeout", 0);
				PlaylistMetadataTimeout = 0;
			}
			waitTime = uint(PlaylistMetadataTimeout);
		}
		
		uint unitIdx = 10;
		if (waitTime == 0 || urls.length() <= unitIdx)
		{
			string joinedUrls = "";
			for (uint i = 0; i < urls.length(); i++) joinedUrls += " " + urls[i];
			
			HostIncTimeOut(2000000);
			uint startTime = HostGetTickCount();
			output = HostExecuteProgram(tx.qt(exePath), options + " --" + joinedUrls);
			
			if (cfg.csl > 0)
			{
				uint cnt = _countJson(output, false);
				uint elapsedTime = (HostGetTickCount() - startTime)/1000;
				string msg = "";
				{
					msg += "  Count: " + cnt;
					msg += "\t\tTime: " + elapsedTime + " sec";
					msg += "\r\n";
					msg += (cnt == 0) ? "  Failed to get." : "  Complete.";
					msg += "\r\n";
				}
				HostPrintUTF8(msg);
			}
		}
		else	// waitTime > 0
		{
			if (cfg.csl > 0)
			{
				string msg = isResponsive ? "  playlist_items_timeout: " : "  playlist_metadata_timeout: ";
				msg += waitTime + " sec";
				HostPrintUTF8(msg);
			}
			uint cnt = 0;
			bool complete = false;
			uint startTime = HostGetTickCount();
			for (uint i = 0; i < urls.length(); i += unitIdx)
			{
				HostIncTimeOut(300000);
				string joinedUrls = "";
				for (uint j = i; j < i + unitIdx; j++)
				{
					joinedUrls += " " + urls[j];
					if (j >= urls.length() - 1) {complete = true; break;}
				}
				string addOutput = HostExecuteProgram(tx.qt(exePath), options + " --" + joinedUrls);
				uint addCnt = _countJson(addOutput, false);
				uint elapsedTime = (HostGetTickCount() - startTime)/1000;
				if (addCnt > 0)
				{
					output += addOutput;
					cnt += addCnt;
					if (cfg.csl > 0)
					{
						string msg = "  Count: " + cnt;
						msg += "\t\tTime: " + elapsedTime + " sec";
						HostPrintUTF8(msg);
					}
				}
				if (complete) break;
				if (elapsedTime >= waitTime) break;
			}
			if (cfg.csl > 0)
			{
				string msg2;
				if (cnt == 0) msg2 = "  Failed to get.\r\n";
				else if (complete) msg2 = "  Complete.\r\n";
				else msg2 = "  Time out.\r\n";
				HostPrintUTF8(msg2);
			}
		}
		output.replace("\r\n{", "{");
		return output;
	}
	
	string getThumbnail(string url)
	{
		array<string> jsonList = ytd.exec2({url}, 1, false, {}, "Collecting a thumbnail");
		if (jsonList.length() == 1)
		{
			JsonReader reader;
			JsonValue root;
			if (reader.parse(jsonList[0], root))
			{
				if (root.isObject())
				{
					string thumb;
					if (jsn.getValueString(root, "thumbnail", thumb))
					{
						return thumb;
					}
				}
			}
		}
		return "";
	}
	
}

YTDLP ytd;

//---------------------- END of class YTDLP ------------------------



void OnInitialize()
{
	// Called when loading script at first
	
	if (SCRIPT_VERSION.Right(1) == "#")	// debug version
	{
		HostOpenConsole();
	}
	
	cfg.loadFile();
	ytd.checkFileInfo();
	cache.clear();
}


string GetTitle()
{
	// Called when loading script and closing the config panel with ok button
	
	string scriptName = "yt-dlp " + SCRIPT_VERSION;
	if (fc.defCfgError || fc.cstCfgError)
	{
		scriptName += " (CONFIG ERROR)";
	}
	else if (ytd.error > 0)
	{
		scriptName += " " + ytd.errors[ytd.error];
	}
	else if (cfg.getInt("SWITCH", "stop") == 1)
	{
		scriptName += " (STOP)";
	}
	else if (!cfg.getStr("COOKIE", "cookie_file").empty())
	{
		scriptName += " (cookie file)";
	}
	else
	{
		string browser = cfg.getStr("COOKIE", "cookie_browser");
		if (!browser.empty())
		{
			scriptName += " (cookie " + browser + ")";
		}
	}
	return scriptName;
}


string GetConfigFile()
{
	// Called when opening the config panel
	
	fc.showDialog = true;
	cfg.loadFile();
	return SCRIPT_CONFIG_CUSTOM;
}


void ApplyConfigFile()
{
	// Called when closing the config panel with ok button
	
	if (!cfg.loadFile())
	{
		string msg = "The script cannot apply the configuration.";
		HostMessageBox(msg, "[yt-dlp] ERROR: Default Config File", 3, 0);
	}
	if (http.noCurl == 1)
	{
		http.noCurl = 2;
		string msg = 
		"CURL command not found.\r\n"
		"Some features do not work if they need \"curl.exe\".\r\n"
		"Please place \"curl.exe\" in the system32 folder or in any folder accessible to the extension.";
		HostMessageBox(msg, "[yt-dlp] CAUTION: No Curl Command", 0, 1);
	}
	
	cache.clear();
}


string GetDesc()
{
	// Called when opening info panel
	
	if (fc.defCfgError || fc.cstCfgError)
	{
		ytd.checkFileInfo();
	}
	else
	{
		if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 2)
		{
			ytd.updateVersion();
		}
		else
		{
			ytd.checkFileInfo();
			ytd.checkFileHash();
		}
	}
	
	const string SITE_DEV = "https://github.com/yt-dlp/yt-dlp";
	const string SITE_DESC = "https://github.com/hgcat-360/PotPlayer-Extension-by-yt-dlp";
	string info =
		"<a href=\"" + SITE_DEV + "\">yt-dlp development (github)</a>\r\n"
		"<a href=\"" + SITE_DESC + "\">PotPlayer-Extension_yt-dlp (github)</a>\r\n"
		"\r\n"
		"yt-dlp.exe version: ";
	
	if (ytd.error > 0)
	{
		info += "N/A " + ytd.errors[ytd.error];
	}
	else
	{
		info += ytd.version;
	}
	
	if (fc.defCfgError)
	{
		info += "\r\n\r\n"
		"| The following file has a problem:\r\n"
		"| Default config file \"yt-dlp_default.ini\"\r\n";
	}
	else if (fc.cstCfgError)
	{
		info += "\r\n\r\n"
		"| The following file has a problem:\r\n"
		"| User's config file \"yt-dlp.ini\"\r\n";
	}
	else
	{
		switch (ytd.error)
		{
			case 1:
				info += "\r\n\r\n"
				"| Cannot find \"yt-dlp.exe\".\r\n"
				"| Place \"yt-dlp.exe\" in [ytdlp_location]\r\n"
				"| or check the [ytdlp_location] setting.\r\n";
				break;
			case 2:
				info += "\r\n\r\n"
				"| Your \"yt-dlp.exe\" may not be valid.\r\n"
				"| Replace it with a proper one or\r\n"
				"| check the [ytdlp_location] folder.\r\n";
				break;
			case 3:
				info += "\r\n\r\n"
				"| Your \"yt-dlp.exe\" did not work as expected.\r\n"
				"| After checking, set [critical_error] to 0\r\n"
				"| in the config file and reload the script.\r\n";
				break;
		}
	}
	
	return info;
}



bool _IsExtType(string ext, int type)
{
	if (ext.empty()) return false;
	if (ext.Left(1) == ".") ext = ext.substr(1);
	ext.MakeLower();
	
	array<string> extList;
	{
		if (type & 0x1 > 0)	// image
		{
			array<string> imageExtList = {"jpg", "jpeg", "png", "gif", "webp"};
			extList.insertAt(extList.length(), imageExtList);
		}
		if (type & 0x10 > 0)	// video
		{
			array<string> videoExtList = {"avi", "wmv", "wmp", "wm", "asf", "mpg", "mpeg", "mpe", "m1v", "m2v", "mpv2", "mp2v", "ts", "tp", "tpr", "trp", "vob", "ifo", "ogm", "ogv", "mp4", "m4v", "m4p", "m4b", "3gp", "3gpp", "3g2", "3gp2", "mkv", "rm", "ram", "rmvb", "rpm", "flv", "swf", "mov", "qt", "amr", "nsv", "dpg", "m2ts", "m2t", "mts", "dvr-ms", "k3g", "skm", "evo", "nsr", "amv", "divx", "webm", "wtv", "f4v", "mxf"};
			extList.insertAt(extList.length(), videoExtList);
		}
		if (type & 0x100 > 0)	// audio
		{
			array<string> audioExtList = {"wav", "wma", "mpa", "mp2", "m1a", "m2a", "mp3", "ogg", "m4a", "aac", "mka", "ra", "flac", "ape", "mpc", "mod", "ac3", "eac3", "dts", "dtshd", "wv", "tak", "cda", "dsf", "tta", "aiff", "aif", "aifc" "opus", "amr"};
			extList.insertAt(extList.length(), audioExtList);
		}
		if (type & 0x1000 > 0)	// playlist
		{
			array<string> playlistExtList = {"m3u8", "m3u", "asx", "pls", "wvx", "wax", "wmx", "cue", "mpls", "mpl", "xspf", "mpd", "dpl"};
				// exclude "xml", "rss"
			extList.insertAt(extList.length(), playlistExtList);
		}
		if (type & 0x10000 > 0)	// subtitles
		{
			array<string> subtitleExtList = {"smi", "srt", "idx", "sub", "sup", "psb", "ssa", "ass", "txt", "usf", "xss.*.ssf", "rt", "lrc", "sbv", "vtt", "ttml", "srv"};
			extList.insertAt(extList.length(), subtitleExtList);
		}
		if (type & 0x100000 > 0)	// compressed
		{
			array<string> compressedExtList = {"zip", "rar", "tar", "7z", "gz", "xz", "cab", "bz2", "lzma", "rpm"};
			extList.insertAt(extList.length(), compressedExtList);
		}
		if (type & 0x1000000 > 0)	// xml, rss
		{
			array<string> xmlExtList = {"xml", "rss"};
			extList.insertAt(extList.length(), xmlExtList);
		}
	}
	
	if (extList.find(ext) >= 0) return true;
	return false;
}

bool _IsBasicMediaExt(string path)
{
	string ext = HostGetExtension(path);
	if (!ext.empty())
	{
		if (ext.Left(1) == ".") ext = ext.substr(1);
		ext.MakeLower();
		
		array<string> extList = {
			"mp4", "mkv", "ts", "wmv", "webm", 
			"mp3", "flac", "m4a",
			"jpg", "png", "gif", "webp"
		};
		if (extList.find(ext) >= 0)
		{
			return true;
		}
	}
	return false;
}


bool _IsUrlSite(string url, string website)
{
	// Check multiple urls
	int pos = url.findFirstNotOf(" ");
	if (pos < 0) return false;
	if (pos > 0) url = url.substr(pos);
	pos = url.find(" ");
	if (pos > 0) url.Left(pos);
	
	if (url.empty()) return false;
	url.MakeLower();
	website.MakeLower();
	
	if (website == "youtube")
	{
		if (HostRegExpParse(url, "^https?://(?:[-\\w.]+\\.)?youtube\\.com(?:[/?#].*)?$", {})) return true;
		if (HostRegExpParse(url, "^https?://(?:[-\\w.]+\\.)?youtu\\.be(?:[/?#].*)?$", {})) return true;
	}
	else if (website == "kakao")
	{
		if (HostRegExpParse(url, "//(?:[-\\w.]+\\.)?kakao\\.com(?:[/?#].*)?$", {})) return false;
	}
	else if (website == "shoutcast")
	{
		if (HostRegExpParse(url, "^http://yp\\.shoutcast\\.com/sbin/tunein\\-station\\.(?:pls|m3u|xspf)\\?id=\\d+", {})) return true;
	}
	else if (website.find(".") >= 0)	// if not ".com"
	{
		website.replace(".", "\\.");
		if (HostRegExpParse(url, "^https?://(?:[-\\w.]+\\.)?" + website + "(?:[/?#].*)?$", {})) return true;
	}
	else
	{
		if (HostRegExpParse(url, "^https?://(?:[-\\w.]+\\.)?" + website + "\\.com(?:[/?#].*)?$", {})) return true;
	}
	
	return false;
}


string _ReviseUrl(string url)
{
	//url = HostUrlDecode(url);
	
	if (url.Left(1) == "<")
	{
		// Remove the time range if exists
		int pos = url.find(">", 0);
		if (pos >= 0) url = url.substr(pos + 1);
	}
	
	if (url.Left(ytd.SCHEME.length()) == ytd.SCHEME)
	{
		url = url.substr(ytd.SCHEME.length());
	}
	
	return url;
}


string _GetYoutubeVideoId(string url)
{
	if (_IsUrlSite(url, "youtube"))
	{
		string idStr = HostRegExpParse(url, "[?&]v=([-\\w]+)");
		return idStr;
	}
	return "";
}

string _GetYoutubeChannelUrl(string url)
{
	int pos = url.find("://");
	if (pos < 0) return "";	// no URL
	pos = url.find(" ");
	if (pos >= 0) return "";	// joinedUrls
	
	string channel = tx.getRegExp(url, "(?i)^https?://www\\.youtube\\.com/@[^/?#]+");
	if (channel.empty())
	{
		channel = tx.getRegExp(url, "(?i)^https?://www\\.youtube\\.com/channel/[-\\w]+");
	}
	if (!channel.empty()) return channel;
	return "";
}

int _YoutubeChannel(string url)
{
	string channel = _GetYoutubeChannelUrl(url);
	if (!channel.empty())
	{
		channel += "/";
		if (url.Right(1) != "/") url += "/";
		if (url.length() == channel.length())
		{
			return 2;	// top channel
		}
		else
		{
			return 1;	// channel tab
		}
	}
	return 0;
}

string _ChangeUrlYoutubeChannelTop(string url)
{
	// YouTube channel top url -> 3 YouTube tabs
	if (_YoutubeChannel(url) == 2)	// top channel
	{
		if (url.Right(1) != "/") url += "/";
		string joinedUrls = "";
		joinedUrls += url + "videos ";
		joinedUrls += url + "streams ";
		joinedUrls += url + "shorts";
		return joinedUrls;
	}
	return "";
}


string _GetYoutubeChannelTab(string url)
{
	string channel = _GetYoutubeChannelUrl(url);
	if (!channel.empty())
	{
		int len = channel.length();
		if(url.substr(len, 1) == "/")
		{
			string tab = url.substr(len + 1);
			if (tab.find("/") < 0)
			{
				tab.MakeLower();
				return tab;
			}
		}
	}
	return "";
}

bool _IsYoutubeTabPlaylistType(string url)
{
	array<string> playlistTabs = {"featured", "playlists", "releases", "podcasts"};
	string tab = _GetYoutubeChannelTab(url);
	if (!tab.empty())
	{
		if (playlistTabs.find(tab) >= 0) return true;
	}
	return false;
}


int _CheckBiliPart(string url)
{
	url.MakeLower();
	if (HostRegExpParse(url, "^https://www\\.bilibili\\.com/video/\\w+", {}))
	{
		int idx = parseInt(HostRegExpParse(url, "[?&]p=(\\d+)\\b"));
		if (idx > 0)
		{
			// bilibili part index (?p=1 etc.)
			return idx;
		}
		else
		{
			// possibly bilibili part
			return 0;
		}
	}
	return -1;
}

bool _IsPotentialBiliPart(string url)
{
	if (_CheckBiliPart(url) == 0) return true;
	return false;
}

string _GetChatUrl(string url)
{
	string chatUrl = "";
	
	string youtubeId = _GetYoutubeVideoId(url);
	if (!youtubeId.empty())
	{
		chatUrl = "https://www.youtube.com/live_chat?v=" + youtubeId + "&is_popout=1";
	}
	else if (_IsUrlSite(url, "twitch.tv"))
	{
		if (url.replace("twitch.tv/", "twitch.tv/popout/") > 0)
		{
			int pos = url.find("?");
			if (pos > 0) url = url.Left(pos);
			if (url.Right(1) != "/") url += "/";
			url += "chat";
			chatUrl = url;
		}
	}
	else if (_IsUrlSite(url, "kick.com"))
	{
		if (url.replace("kick.com/", "kick.com/popout/") > 0)
		{
			int pos = url.find("?");
			if (pos > 0) url = url.Left(pos);
			if (url.Right(1) != "/") url += "/";
			url += "chat";
			chatUrl = url;
		}
	}
	else if (_IsUrlSite(url, "rumble"))
	{
		string data = HostUrlGetString(url);
		if (data.length() > 1000)
		{
			string numId = HostRegExpParse(data, "\\{[^}]*\"video_id\": ?(\\d+)");
			if (!numId.empty())
			{
				chatUrl = "https://rumble.com/chat/popup/" + numId;
			}
		}
	}
	/*
	else if (_IsUrlSite(url, "sooplive.co.kr"))	// new Africa TV
	{
		chatUrl = url + "?vtype=chat";
	}
	*/
	return chatUrl;
}

string _GetUrlExtension(string url)
{
	url.MakeLower();
	string ext = HostRegExpParse(url, "^https?://[^\\?#]+/[^/?#]+\\.(\\w+)(?:[?#].+)?$");
	return ext;
}


int _WebsitePlaylistMode(string url)
{
	int mode = cfg.getInt("TARGET", "website_playlist_standard");
	if (mode < 0 || mode > 2) mode = 0;
	string domain = _GetUrlDomain(url);
	
	string data = cfg.getStr("TARGET", "website_playlist_each");
	data.MakeLower();
	array<string> arrData = tx.trimSplit(data, ",");
	
	for (uint i = 0; i < arrData.length(); i++)
	{
		array<string> item = tx.trimSplit(arrData[i], ":");
		if (item.length() == 2)
		{
			string _domain = item[0];
			if (domain.find(_domain) >= 0)
			{
				int _mode = parseInt(item[1]);
				if (_mode >= 0 && _mode <= 2)
				{
					mode = _mode;
					break;
				}
			}
		}
	}
	return mode;
}


bool _PlayitemCheckBase(string url)
{
	if (fc.defCfgError || fc.cstCfgError) return false;
	
	if (ytd.error == 3 || cfg.getInt("SWITCH", "stop") == 1) return false;
		// Error or stopped state
	
	if (HostRegExpParse(url, "//192\\.168\\.\\d+\\.\\d+\\b", {})) return false;
		// LAN
	
	if (!HostRegExpParse(url, "https?://", {})) return false;
		// No web
	
	if (url.find("live://tv.kakao.com/") >= 0) return false;
		// KakaoTV live
	
	return true;
}


void PlaylistCancel()
{
	// Treat only online content
	// Output is suspended, but background processing continues.
//HostPrintUTF8("PlaylistCancel\r\n");
	hist.cancelAll();
}

void PlayitemCancel()
{
	// Treat only online content
	// Output is suspended, but background processing continues.
//HostPrintUTF8("PlayitemCancel\r\n");
	hist.cancelAll();
}

bool PlaylistCheck(const string &in path)
{
	// Called when a new item is being opend from a location other than PotPlayer's album
//HostPrintUTF8("PlaylistCheck\r\n");
	
	string url = _ReviseUrl(path);
	
	if (!_PlayitemCheckBase(url))
	{
		return false;
	}
	
	if (ytd.playlistForceExpand > 0) return true;
	if (cfg.getInt("TARGET", "playlist_expand_mode") == -1) return true;
	
	if (_IsUrlSite(url, "shoutcast")) return true;
	
	string ext = _GetUrlExtension(url);
	if (_IsExtType(ext, 0x1000000))	// xml/rss file
	{
		if (cfg.getInt("TARGET", "rss_playlist") == 1) return true;
		if (ext == "rss") return false;
	}
	if (_IsExtType(ext, 0x100))	// audio files
	{
		return (cfg.getInt("TARGET", "radio_thumbnail") == 1);
	}
	if (_IsExtType(ext, 0x111011))	// other direct files
	{
		if (ext == "m3u8")
		{
			if (cfg.getInt("TARGET", "m3u8_hls") == 1) return true;
		}
		return false;
	}
	
	if (_IsUrlSite(url, "youtube"))
	{
		int enableYoutube = cfg.getInt("YOUTUBE", "enable_youtube");
		if (enableYoutube == 2 || enableYoutube == 3) return true;
		return false;
	}
	
	return true;
	//return (_WebsitePlaylistMode(url) > 0);
}


string _CutOffString(string desc)
{
	int MINI_LENGTH = 30;
	int titleMaxLen = cfg.getInt("FORMAT", "title_max_length");
	if (titleMaxLen > 0)
	{
		if (titleMaxLen < MINI_LENGTH)
		{
			cfg.setInt("FORMAT", "title_max_length", MINI_LENGTH);
			titleMaxLen = MINI_LENGTH;
		}
		desc = tx.cutOffString(desc, uint(titleMaxLen));
	}
	else if (titleMaxLen < 0)
	{
		cfg.setInt("FORMAT", "title_max_length", 0);
		titleMaxLen = 0;
	}
	return desc;
}


string _GetRadioThumb(string type = "")
{
	string fn;
	if (type == "icecast") fn = RADIO_IMAGE_1;
	else if (type == "shoutcast") fn = RADIO_IMAGE_1;
	else fn = RADIO_IMAGE_2;
	fn = HostGetScriptFolder() + fn;
	if (HostFileExist(fn))
	{
		return ("file://" + fn);
	}
	return "";
}


string _GetPlaylistThumb()
{
	string fn = HostGetScriptFolder() + PLAYLIST_IMAGE;
	if (HostFileExist(fn))
	{
		return ("file://" + fn);
	}
	return "";
}


bool _SetOrdinaryAudioThumb(array<dictionary> &out MetaDataList, string url)
{
	if (cfg.getInt("TARGET", "radio_thumbnail") == 1)
	{
		dictionary MetaData;
		MetaData["url"] = url;
		MetaData["thumbnail"] = _GetRadioThumb();
		MetaDataList.insertLast(MetaData);
		return true;
	}
	return false;
}


bool _CheckRss(string url, string &out imgUrl)
{
	string data = http.getContent(url, 5, 2047);
	if (!data.empty())
	{
		int pos1 = data.find("<rss");
		if (pos1 >= 0)
		{
			pos1 = data.find("<channel>", pos1);
			if (pos1 > 0)
			{
				int pos2 = data.find("<item>", pos1);
				if (pos2 > 0)
				{
					string chHead = data.substr(pos1, pos2 - pos1);
					
					// Get the channel image, if available
					string imgTag = HostRegExpParse(chHead, "<(?:\\w+:)?image(?:Link)?>(.+?)</(?:\\w+:)?image(?:Link)?>");
					if (!imgTag.empty())
					{
						imgUrl = HostRegExpParse(imgTag, "\\b(http[^<\n]+\\.(?:jpg|png|gif))[<\n]");
					}
					else
					{
						imgUrl = HostRegExpParse(data, "<(?:\\w+:)?image(?:Link)? href=\"([^\"]+)\"");
					}
					return true;
				}
			}
		}
	}
	return false;
}


bool _IsUrlPlaylist(string url)
{
	if (_IsUrlSite(url, "youtube"))
	{
		if (tx.findRegExp(url, "[?&]list=") > 0) return true;
		if (_YoutubeChannel(url) > 0) return true;
	}
	return false;
}


int _CheckMetaDataPlaylist(dictionary &MetaData)
{
	int playlistSelfCnt = int(MetaData["playlistSelfCount"]);
	if (playlistSelfCnt > 0) return 2;
	
	string url = string(MetaData["webUrl"]);
	if (_IsUrlPlaylist(url)) return 1;
	
	return 0;
}


array<string> _RemoveEntryYoutubeTab(array<string> jsonList)
{
	array<string> outJsonList = {};
	uint n = 0;
	for (uint i = 0; i < jsonList.length(); i++)
	{
		string url = jsn.getDirectValueString(jsonList[i], "webpage_url");
		if (!_GetYoutubeChannelTab(url).empty())
		{
			// remove
			n++;
		}
		else
		{
			outJsonList.insertLast(jsonList[i]);
		}
	}
	if (n > 0)
	{
		if (cfg.csl > 0)
		{
			string msg = "  remove tab items: " + n + "\r\n";
			HostPrintUTF8(msg);
		}
	}
	return outJsonList;
}

array<string> _MakeUrlArrayAll(array<string> jsonList)
{
	array<string> urls = {};
	for (uint i = 0; i < jsonList.length(); i++)
	{
		string url = jsn.getDirectValueString(jsonList[i], "webpage_url");
		if (!url.empty()) urls.insertLast(url);
	}
	return urls;
}

uint _GetAllCount(array<string> jsonList)
{
	uint allCnt = 0;
	for (uint i = 0; i < jsonList.length(); i++)
	{
		int cnt = jsn.getDirectValueInt(jsonList[i], "playlist_count");
		if (cnt > 0) allCnt += cnt;
	}
	return allCnt;
}


array<string> _MakeUrlArrayMetadata1(array<dictionary> MetaDataList, uint type, array<uint> &out arrIdx, bool &out existTitle)
{
	array<string> urls = {};
	arrIdx = {};
	existTitle = false;
	
	for (uint i = 0; i < MetaDataList.length(); i++)
	{
		int make = 0;
		
		if ((type & 0x1) > 0 && string(MetaDataList[i]["title"]).empty())
		{
			make = 3;
		}
		else if ((type & 0x10) > 0 && _CheckMetaDataPlaylist(MetaDataList[i]) == 1)
		{
			make = 2;
		}
		else if ((type & 0x100) > 0 && string(MetaDataList[i]["thumbnail"]).empty())
		{
			make = 1;
		}
		else if ((type & 0x1000) > 0 && string(MetaDataList[i]["duration"]).empty())
		{
			make = 1;
		}
		
		if (make > 0)
		{
			urls.insertLast(string(MetaDataList[i]["webUrl"]));
			arrIdx.insertLast(i);
		}
		if ((type & 0x1) > 0 && make < 3)
		{
			existTitle = true;
		}
	}
	
	return urls;
}

array<string> _MakeUrlArrayMetadata2(array<dictionary> MetaDataList, array<uint> &out arrIdx)
{
	array<string> urls = {};
	arrIdx = {};
	for (uint i = 0; i < MetaDataList.length(); i++)
	{
		if (!string(MetaDataList[i]["title"]).empty())
		{
			if (string(MetaDataList[i]["thumbnail"]).empty())
			{
				if (_CheckMetaDataPlaylist(MetaDataList[i]) > 0)
				{
					urls.insertLast(string(MetaDataList[i]["webUrl"]));
					arrIdx.insertLast(i);
				}
			}
		}
	}
	return urls;
}

bool _MatchIds(string url, array<string> ids)
{
	for (uint i = 0; i < ids.length(); i++)
	{
		if (ids[i].empty()) continue;
		if (url.find(ids[i]) >= 0) return true;
	}
	return false;
}

string _GetPageTitle(string url)
{
	string data = HostUrlGetString(url);
	//string data = http.getHeader(url, 3000);
	if (!data.empty())
	{
		string head = HostRegExpParse(data, "<head\\b.*?>([\\S\\s]*?)</head>");
		if (head.empty()) head = HostRegExpParse(data, "<head\\b.*?>([\\S\\s]*)$");
		if (!head.empty())
		{
			string title = HostRegExpParse(head, "<title\\b.*?>(.*?)</title>");
			return title;
		}
	}
	return "";
}


string _GetPlaylistNote(string url, uint playlistSelfCnt, string author, string extractor)
{
	string note;
	{
		note += "<Playlist";
		if (playlistSelfCnt > 0)
		{
			note += ": " + playlistSelfCnt;
		}
		note += ">";
		if (!author.empty() && (_YoutubeChannel(url) > 0 || _IsPotentialBiliPart(url)))
		{
			note += " " + author;
		}
		else if (!_IsGeneric(extractor))
		{
			note += " @" + extractor;
		}
	}
	return note;
}


string _ReviseThumbnail(string thumb)
{
	if (thumb.Right(4) == ".svg")
	{
		// .svg -> .png (PotPlayer does not support svg)
		thumb = thumb.Left(thumb.length() - 4) + ".png";
	}
	
	if (false)
	//if (!isPlaylist)
	{
		int pos = tx.findRegExp(thumb, "\\.(?:jpg|webp|png)(\\?)");
		if (pos > 0)
		{
			// Remove URL parameter (PotPlayer does not sometimes support it)
			thumb = thumb.Left(pos);
		}
	}
	
	return thumb;
}


bool _ParseWholePlaylist(array<string> jsonList, string inUrl, string &out wholePlaylistTitle)
{
	string jsonString0 = jsonList[0];
	int playlistIdx = jsn.getDirectValueInt(jsonString0, "playlist_index");
	bool isWholePlaylist = (playlistIdx > 0);
	if (isWholePlaylist)
	{
		wholePlaylistTitle = jsn.getDirectValueString(jsonString0, "playlist_title");
		if (wholePlaylistTitle.empty())
		{
			wholePlaylistTitle = _GetPageTitle(inUrl);
			if (wholePlaylistTitle.empty())
			{
				wholePlaylistTitle = "PLAYLIST";
				string extractor = jsn.getDirectValueString(jsonString0, "extractor");
				if (!_IsGeneric(extractor))
				{
					wholePlaylistTitle += " (" + extractor + ")";
				}
			}
		}
		wholePlaylistTitle = _ReviseWebString(wholePlaylistTitle);
		wholePlaylistTitle = _CutOffString(wholePlaylistTitle);
	}
	return isWholePlaylist;
}


int _PlaylistParseDirect(string inUrl, array<dictionary> &MetaDataList)
{
	MetaDataList = {};
	
	if (_IsUrlSite(inUrl, "shoutcast"))
	{
		if (cfg.getInt("TARGET", "shoutcast_playlist") == 1)
		{
			shoutpl.passPlaylist(inUrl, MetaDataList);
			if (cfg.csl > 0)
			{
				HostPrintUTF8("[yt-dlp] Shoutcast playlist was not expanded according to the [shoutcast_playlist] setting. - " + tx.qt(inUrl) + "\r\n\r\n");
			}
		}
		else
		{
			shoutpl.extractPlaylist(inUrl, MetaDataList);
		}
		return 1;
	}
	
	string httpHead = http.getHeader(inUrl, 5);
	
	if (_CheckRadioServer(httpHead))
	{
		if (_SetOrdinaryAudioThumb(MetaDataList, inUrl))
		{
			return 1;
		}
		return -1;
	}
	
	string fileType = _GetFileType(httpHead);
	if (!fileType.empty())
	{
		if (fileType == "audio")
		{
			if (_SetOrdinaryAudioThumb(MetaDataList, inUrl))
			{
				return 1;
			}
		}
		return -1;
	}
	
	return 0;
}


array<dictionary> _PlaylistParse(const string &in path, uint startTime, int playlistForceExpand)
{
	string inUrl = _ReviseUrl(path);
	
	string ext0 = _GetUrlExtension(inUrl);
	
	bool isRss = false;
	string imgUrl;
	if (_IsExtType(ext0, 0x1000000))	// xml/rss file
	{
		if (_CheckRss(inUrl, imgUrl))
		{
			if (cfg.getInt("TARGET", "rss_playlist") == 1)
			{
				isRss = true;
			}
			else
			{
				return {};
			}
		}
	}
	
	int playlistMode;
	if (playlistForceExpand > 0)
	{
		playlistMode = _IsPotentialBiliPart(inUrl) ? 2 : 1;
	}
	else if (isRss)
	{
		playlistMode = 1;
	}
	else
	{
		playlistMode = _WebsitePlaylistMode(inUrl);
	}
	
	array<dictionary> MetaDataList = {};
	
	while (true)
	{
		int prevIdx = hist.findPrev(path, true, startTime, 0);
		if (prevIdx < 0)
		{
			break;
		}
		
		if (playlistForceExpand == 2)
		{
			hist.blockSaveCache(path, true, startTime);
			break;
		}
		
		// previous processing is still working
//HostPrintUTF8("waiting...");
		HostIncTimeOut(3000);
		HostSleep(3000);
		
		if (hist.checkCancel(path, true, startTime, false) > 0)
		{
			return {};
		}
	}
	
	if (playlistForceExpand == 2)
	{
		cache.remove(inUrl, "MetaDataList");
	}
	else
	{
		if (playlistMode > 0)
		{
			MetaDataList = cache.getPlaylist(inUrl);
			if (MetaDataList.length() > 0)
			{
				if (cfg.csl > 0)
				{
					HostPrintUTF8("[yt-dlp] Used cache to add - " + tx.qt(inUrl) + "\r\n");
				}
				return MetaDataList;
			}
		}
		if (playlistForceExpand == 0)
		{
			dictionary MetaData = cache.getItem(inUrl, {});
			if (!MetaData.empty())
			{
				if (cfg.csl > 0)
				{
					HostPrintUTF8("[yt-dlp] Used cache to add - " + tx.qt(inUrl) + "\r\n");
				}
				MetaData["url"] = inUrl;
				MetaDataList.insertLast(MetaData);
				return MetaDataList;
			}
		}
	}
	
	if (_PlaylistParseDirect(inUrl, MetaDataList) != 0)
	{
		// Online radio or online direct files
		return MetaDataList;
	}
	
	array<string> jsonList = {};
	
	if (playlistForceExpand < 2)
	{
		string json = cache.getJson(inUrl, imgUrl);
		if (!json.empty())
		{
			jsonList.insertLast(json);
		}
	}
	if (jsonList.length() == 0)
	{
		// Execute yt-dlp
		jsonList = ytd.exec1(inUrl, (playlistMode == 0 ? 1 : playlistMode));
		if (jsonList.length() == 0) return {};
	}
	
	if (hist.checkCancel(path, true, startTime) == 2) return {};
	
	uint naCnt = 0;	// unavailable count
	uint toCnt = 0;	// time out count
	
	string wholePlaylistTitle = "";
	bool isWholePlaylist = _ParseWholePlaylist(jsonList, inUrl, wholePlaylistTitle);
	
	if (_IsYoutubeTabPlaylistType(inUrl))
	{
		jsonList = _RemoveEntryYoutubeTab(jsonList);
		
		if (cfg.getInt("YOUTUBE", "keep_tab_playlist") != 1)
		{
			// Extract all nested playlists
			array<string> urls = _MakeUrlArrayAll(jsonList);
			if (urls.length() > 0)
			{
				jsonList = ytd.exec2(urls, 0, true);
			}
		}
		if (hist.checkCancel(path, true, startTime) == 2) return {};
	}
	
	uint parseTime1 = HostGetTickCount();
	{
		for (uint i = 0; i < jsonList.length(); i++)
		{
			dictionary MetaData = _ParseMetaData(jsonList[i], inUrl, imgUrl, true);
			if (string(MetaData["webUrl"]).empty()) break;
			MetaDataList.insertLast(MetaData);
		}
	}
	uint parseTime2 = HostGetTickCount();
	uint parseTime = (parseTime2 - parseTime1)/1000;
	if (cfg.csl > 1 && parseTime > 4)
	{
		HostPrintUTF8("JSON list parsing time: " + parseTime + " sec\r\n");
	}
	
	if (MetaDataList.length() == 0) return {};
	
	if (ext0 == "m3u8")
	{
		if (_CheckM3u8Hls(inUrl) > 0)
		{
			HostPrintUTF8("[yt-dlp] This URL is for an HLS stream. - " + tx.qt(inUrl) + "\r\n\r\n");
			return MetaDataList;
		}
	}
	
	string extractor = string(MetaDataList[0]["extractor"]);
	
	array<uint> arrIdx = {};
	bool existTitle = false;
	array<string> urls = _MakeUrlArrayMetadata1(MetaDataList, 0x11, arrIdx, existTitle);
//HostPrintUTF8("urls.length: " + urls.length());
	bool flatPlaylist = existTitle;
	if (urls.length() > 0)
	{
		// Need collecting more metadata.
		string execMsg = "";
		uint sampleMax = 3;
		if (playlistMode == 0 && urls.length() > sampleMax)
		{
			// Not necessary to get all items
			urls.removeRange(sampleMax, urls.length() - sampleMax);
			execMsg = "Sampling metadata";
		}
		array<string> errIds = {};
		array<string> jsonList2 = ytd.exec2(urls, _IsUrlSite(inUrl, "youtube") ? 1 : -1, flatPlaylist, errIds, execMsg);
		
		if (hist.checkCancel(path, true, startTime) == 2) return {};
		
		// Remove error items
		for (uint i = 0; i < jsonList2.length(); i++)
		{
			dictionary @MetaData0 = MetaDataList[arrIdx[i]];
			
			while (MetaData0 !is null)
			{
				if (_MatchIds(string(MetaData0["webUrl"]), errIds))
				{
					naCnt++;
					MetaDataList.removeAt(arrIdx[i]);
					arrIdx.removeAt(i);
					for (uint j = i; j < arrIdx.length(); j++)
					{
						arrIdx[j] = arrIdx[j] - 1;
					}
					@MetaData0 = MetaDataList[arrIdx[i]];
					continue;
				}
				break;
			}
		}
		
		// Collect metadata
		for (uint i = 0; i < jsonList2.length(); i++)
		{
			dictionary MetaData1 = _ParseMetaData(jsonList2[i], inUrl, imgUrl, true);
			dictionary @MetaData0 = MetaDataList[arrIdx[i]];
			string url1 = string(MetaData1["webUrl"]);
			string url0 = string(MetaData0["webUrl"]);
			
			int playlistIdx = int(MetaData1["playlistIndex"]);
			bool isSelfPlaylist = (playlistIdx > 0);
			if (isSelfPlaylist)	// for playlist
			{
				int playlistSelfCnt = int(MetaData1["playlistCount"]);
				if (playlistSelfCnt > 0)
				{
					MetaData0["playlistSelfCount"] = playlistSelfCnt;
				}
				
				if (string(MetaData0["playlistNote"]).empty())
				{
					string author = string(MetaData1["author"]);
					string playlistNote = _GetPlaylistNote(inUrl, playlistSelfCnt, author, extractor);
					if (!playlistNote.empty())
					{
						MetaData0["playlistNote"] = playlistNote;
						MetaData0["author"] = playlistNote;
						MetaData0["originalAuthor"] = author;
					}
				}
			}
			else
			{
				string author = string(MetaData1["author"]);
				if  (!author.empty())
				{
					MetaData0["author"] = author;
				}
			}
			
			string title;
			if (isSelfPlaylist)
			{
				title = string(MetaData1["playlistTitle"]);
			}
			else
			{
				title = string(MetaData1["title"]);
			}
			if (!title.empty())
			{
				MetaData0["title"] = title;
			}
			
			if (playlistIdx < 2 || _IsPotentialBiliPart(url0))
			{
				string thumb = string(MetaData1["thumbnail"]);
				if (!thumb.empty())
				{
					MetaData0["thumbnail"] = thumb;
				}
			}
			
			if (isSelfPlaylist)
			{
				MetaData0["duration"] = "";
			}
			else
			{
				string duration = string(MetaData1["duration"]);
				if (!duration.empty())
				{
					MetaData0["duration"] = duration;
				}
			}
			
			if (playlistMode == 0)
			{
				if (!string(MetaData0["title"]).empty())
				{
					// Enough to get only a single valid item
					break;
				}
			}
		}
	}
	
	if (MetaDataList.length() == 1)
	{
		if (!isWholePlaylist || playlistMode == 0)	// not a playlist
		{
			if (bool(MetaDataList[0]["isAudio"]))	// audio
			{
				// Treat the audio clip as a playlist to set the thumbnail
			}
			else if (!string(MetaDataList[0]["title"]).empty())
			{
				// Treat the URL as a playlist that contains only a single video.
			}
			else
			{
				MetaDataList = {};
			}
		}
	}
	
	bool removeNoData = (cfg.getInt("TARGET", "playlist_without_metadata") != 1);
	if (MetaDataList.length() > 0)
	{
		// Remove items if their metadata has not been collected yet
		if (removeNoData)
		{
			for (int i = 0; i < int(MetaDataList.length()); i++)
			{
				if (string(MetaDataList[uint(i)]["title"]).empty())
				{
					toCnt++;
					MetaDataList.removeAt(i);
					i--; continue;
				}
			}
		}
		else
		{
			for (int i = 0; i < int(MetaDataList.length()); i++)
			{
				if (string(MetaDataList[uint(i)]["title"]).empty())
				{
					// just count
					toCnt++;
				}
			}
		}
		
		// Remove unavailable videos on YouTube
		if (_IsUrlSite(inUrl, "youtube"))
		{
			for (int i = 0; i < int(MetaDataList.length()); i++)
			{
				dictionary @MetaData = MetaDataList[uint(i)];
				if (_CheckMetaDataPlaylist(MetaData) == 0)
				{
					string thumb = string(MetaData["thumbnail"]);
					if (thumb.find("no_thumbnail.") >= 0)
					{
						naCnt++;
						MetaDataList.removeAt(i);
						i--; continue;
					}
				}
			}
		}
		
		// Get the thumbnail of playlist items
		array<string> urls2;
		array<uint> arrIdx2 = {};
		if (isWholePlaylist && playlistMode == 0)
		{
			urls2 = {inUrl};
			arrIdx2 = {0};
			flatPlaylist = false;
		}
		else
		{
			urls2 = _MakeUrlArrayMetadata2(MetaDataList, arrIdx2);
		}
//HostPrintUTF8("urls2.length: " + urls2.length());
		
		if (urls2.length() > 0)
		{
			array<string> jsonList2 = ytd.exec2(urls2, 1, flatPlaylist, {}, "Collecting " + (urls2.length() == 1 ? "a thumbnail" : "thumbnails"));
			
			if (hist.checkCancel(path, true, startTime) == 2) return {};
			
			for (uint i = 0; i < jsonList2.length(); i++)
			{
				dictionary @MetaData0 = MetaDataList[arrIdx2[i]];
				
				string thumb = jsn.getDirectValueString(jsonList2[i], "thumbnail");
				if (thumb.empty())
				{
					thumb = jsn.getDirectValueString(jsonList2[i], "thumbnails", "url");
				}
				if (!thumb.empty())
				{
					thumb = _ReviseThumbnail(thumb);
					MetaData0["thumbnail"] = thumb;
				}
			}
		}
		
		if (isWholePlaylist && playlistMode == 0)
		{
			dictionary MetaData = {};
			dictionary @MetaData0 = MetaDataList[0];
			
			MetaData["webUrl"] = inUrl;
			MetaData["url"] = inUrl;
			
			MetaData["extractor"] = extractor;
			
			string title = wholePlaylistTitle;
			MetaData["title"] = title;
			
			string thumb = string(MetaData0["thumbnail"]);
			if (thumb.empty())
			{
				thumb = _GetPlaylistThumb();
			}
			MetaData["thumbnail"] = thumb;
			MetaData["playUrl"] = thumb;
			
			MetaData["duration"] = "";
			
			uint playlistSelfCnt = MetaDataList.length();
			//uint playlistSelfCnt = uint(MetaData0["playlistCount"]);
			MetaData["playlistSelfCount"] = playlistSelfCnt;
			string playlistNote = string(MetaData0["playlistNote"]);
			
			string author = string(MetaData0["originalAuthor"]);
			if (author.empty()) author = string(MetaData0["author"]);
			
			playlistNote = _GetPlaylistNote(inUrl, playlistSelfCnt, author, extractor);
			if (!playlistNote.empty())
			{
				MetaData["playlistNote"] = playlistNote;
				MetaData["author"] = playlistNote;
				MetaData["originalAuthor"] = author;
			}
			
			// MetaDataList has only a single MetaData
			MetaDataList.resize(0);
			MetaDataList.insertLast(MetaData);
		}
		
		if (MetaDataList.length() == 1 && inUrl != string(MetaDataList[0]["url"]))
		{
			if (!isWholePlaylist || playlistMode == 0)
			{
				MetaDataList[0]["url"] = inUrl;
			}
		}
		
		// Keep the hash of yt-dlp.exe, which works without issues.
		if (!ytd.tmpHash.empty())
		{
			if (ytd.tmpHash != cfg.getStr("MAINTENANCE", "ytdlp_hash"))
			{
				cfg.setStr("MAINTENANCE", "ytdlp_hash", ytd.tmpHash);
			}
		}
		ytd.backupExe();
		
		if (hist.checkCancel(path, true, startTime) == 2) return {};
		
		if (MetaDataList.length() == 1)
		{
			if (!isWholePlaylist)	// not a playlist, just an item
			{
				cache.addJson(inUrl, jsonList[0], string(MetaDataList[0]["thumbnail"]));
			}
			else if (playlistMode == 0)	// non-expanded playlist
			{
				cache.addItem(inUrl, MetaDataList[0], {});
			}
			else	// playlist including only one item
			{
				cache.addPlaylist(inUrl, MetaDataList);
			}
		}
		else	// playlist including multiple items
		{
			cache.addPlaylist(inUrl, MetaDataList);
		}
	}
	
	if (hist.checkCancel(path, true, startTime) > 0) return {};
	
	if (cfg.csl > 0)
	{
		if (MetaDataList.length() > 0)
		{
			HostPrintUTF8("\r\n[yt-dlp] Extracting entries complete (" + extractor + "). - " + tx.qt(inUrl) +"\r\n");
			
			if (isWholePlaylist)
			{
				string msg;
				if (playlistMode > 0)
				{
					if (toCnt > 0 || naCnt > 0)
					{
						msg += "  Items extracted: " + MetaDataList.length() + "\r\n";
						if (toCnt > 0)
						{
							msg += "  Timed-out / error items: " + toCnt + "  (" + (removeNoData ? "removed" : "included") + ")\r\n";
						}
						if (naCnt > 0)
						{
							msg += "  Unavailable items: " + naCnt + "  (removed)\r\n";
						}
						msg += "\r\n";
					}
					msg += "Playlist Title: " + wholePlaylistTitle + "\r\n";
					msg += "Playlist Count: " + MetaDataList.length() + "\r\n";
				}
				else
				{
					msg += "Playlist Title: " + wholePlaylistTitle + "\r\n";
					msg += "Playlist Count: " + int(MetaDataList[0]["playlistSelfCount"]) + "\r\n";
				}
				HostPrintUTF8(msg);
			}
		}
		else	// no MetaDataList
		{
			HostPrintUTF8("\r\n[yt-dlp] Extracting entries failed. - " + tx.qt(inUrl) +"\r\n");
		}
	}
	return MetaDataList;
}


array<dictionary> PlaylistParse(const string &in path)
{
	// Called after PlaylistCheck if it returns true
//HostPrintUTF8("PlaylistParse - " + path + "\r\n");
	
	if (cfg.csl > 0) HostOpenConsole();
	
	int playlistForceExpand = ytd.playlistForceExpand;
	ytd.playlistForceExpand = 0;
	
	int playlistExpandMode = cfg.getInt("TARGET", "playlist_expand_mode");
	if (playlistExpandMode == -1)
	{
		// apply for the new PotPlayer window
		playlistExpandMode = 10;
		cfg.setInt("TARGET", "playlist_expand_mode", playlistExpandMode, true);
		playlistForceExpand = 1;
	}
	
	array<dictionary> MetaDataList = {};
	
	uint startTime = HostGetTickCount();
	hist.add(path, true, startTime);
	{
		MetaDataList = _PlaylistParse(path, startTime, playlistForceExpand);
	}
	hist.remove(path, true, startTime);
	
	_BlockAutoRestore(MetaDataList, path, startTime, playlistExpandMode);
	
	return MetaDataList;
}


bool _BlockAutoRestore(array<dictionary> &MetaDataList, string path, uint startTime, int playlistExpandMode)
{
	if (playlistExpandMode != 1 && playlistExpandMode != 2) return false;
	if (MetaDataList.length() == 0) return false;
	
	string prevPath = __BlockAutoRestoreAlbum(path, startTime);
	if (!prevPath.empty())
	{
		string prevUrl = _ReviseUrl(prevPath);
		if (prevPath == path)
		{
			array<dictionary> insertList;
			for (uint i = 0; i < 3; i++)
			{
				insertList = cache.getPlaylist(prevUrl);
				if (insertList.length() > 0) break;
				HostSleep(3000);
			}
//HostPrintUTF8("insertList.length: " + insertList.length());
			if (insertList.length() > 0)
			{
				MetaDataList.resize(0);
				MetaDataList.insertAt(0, insertList);
				return true;
			}
		}
		else
		{
			int insertIdx = -1;
			for (uint i = 0; i < MetaDataList.length(); i++)
			{
				if (string(MetaDataList[i]["webUrl"]) == prevUrl)
				{
					insertIdx = i;
					break;
				}
			}
			if (insertIdx >= 0)
			{
				array<dictionary> insertList;
				for (uint i = 0; i < 3; i++)
				{
					insertList = cache.getPlaylist(prevUrl);
					if (insertList.length() > 0) break;
					HostSleep(3000);
				}
				if (insertList.length() > 0)
				{
					MetaDataList.resize(0);
					MetaDataList.insertAt(0, insertList);
					
					/*
					if (playlistExpandMode == 1)
					{
						insertIdx += MetaDataList.length();
					}
					else if (playlistExpandMode == 2)
					{
						insertIdx += 1;
					}
					MetaDataList.insertAt(insertIdx, insertList);
					cache.addPlaylist(_ReviseUrl(path), MetaDataList, true);
					*/
					
					return true;
				}
			}
		}
	}
	
	return false;
}


string __BlockAutoRestoreAlbum(string path, uint startTime)
{
	// Suppress PotPlayer's behavior in the external-playlist album
	
	string prevPath = "";
	bool block = false;
	
	{
		// When expanding a playlist by double trigger
		int curIdx = hist.find(path, true, startTime);
		for (uint i = curIdx + 1; i < hist.list.length(); i++)
		{
			prevPath = string(hist.list[i]["path"]);
			if (prevPath == path)
			{
				//if (bool(hist.list[i]["toAlbum"]))
				{
					if (___BlockAutoRestoreAlbum(i, startTime))
					{
						return prevPath;
					}
				}
			}
		}
	}
	
	string inUrl = _ReviseUrl(path);
	if (_IsYoutubeTabPlaylistType(inUrl))
	{
		// youtube plyalist tab
		int curIdx = hist.find(path, true, startTime);
		for (uint i = curIdx + 1; i < hist.list.length(); i++)
		{
			prevPath = string(hist.list[i]["path"]);
			if (prevPath.find("https://www.youtube.com/playlist?list=") == 0)
			{
				if (___BlockAutoRestoreAlbum(i, startTime))
				{
					return prevPath;
				}
			}
		}
	}
	else if (inUrl.find("https://space.bilibili.com/") == 0)
	{
		// bilibili playlist
		int curIdx = hist.find(path, true, startTime);
		for (uint i = curIdx + 1; i < hist.list.length(); i++)
		{
			prevPath = string(hist.list[i]["path"]);
			if (_IsPotentialBiliPart(prevPath))
			{
				if (___BlockAutoRestoreAlbum(i, startTime))
				{
					return prevPath;
				}
			}
		}
	}
	
	return "";
}


bool ___BlockAutoRestoreAlbum(uint prevIdx, uint startTime)
{
	uint prevStartTime = uint(hist.list[prevIdx]["startTime"]);
	if (startTime >= prevStartTime)
	{
		uint prevFinishTime = uint(hist.list[prevIdx]["finishTime"]);
		if (prevFinishTime == 0)
		{
//HostPrintUTF8("finishTime: 0");
			return true;
		}
		else
		{
			if (startTime < prevFinishTime + 100)
			{
//HostPrintUTF8("diffTime: " + (int(startTime) - int(prevFinishTime)));
				return true;
			}
		}
	}
	return false;
}

bool PlayitemCheck(const string &in path)
{
	// Called when an item is being opened after PlaylistCheck or PlaylistParse
//HostPrintUTF8("PlayitemCheck\r\n");
	
	string url = _ReviseUrl(path);
	url.MakeLower();
	
	if (!_PlayitemCheckBase(url))
	{
		if (false)
		{
			if (_IsBasicMediaExt(url))
			{
				// Only if local content is being opened
//HostPrintUTF8("local item: " + path);
				hist.add(path, false, HostGetTickCount(), false);
				hist.cancelAll();
			}
		}
		return false;
	}
	
	string ext = _GetUrlExtension(url);
	if (ext == "rss") return false;
	if (_IsExtType(ext, 0x111000))	// playlist or other files
	{
		if (ext == "m3u8" || ext == "txt")
		{
			if (cfg.getInt("TARGET", "m3u8_hls") == 1) return true;
		}
		if (_IsUrlSite(url, "shoutcast")) return true;
		return false;
	}
	
	if (_IsUrlSite(url, "youtube"))
	{
		int enableYoutube = cfg.getInt("YOUTUBE", "enable_youtube");
		if (enableYoutube != 1 && enableYoutube != 2) return false;
	}
	
	return true;
}


void _PlayerAddList(string url, bool reload)
{
	int playlistExpandMode = cfg.getInt("TARGET", "playlist_expand_mode");
	if (playlistExpandMode == 10)
	{
		cfg.setInt("TARGET", "playlist_expand_mode", -1, true);
	}
	else
	{
		ytd.playlistForceExpand = reload ? 2 : 1;
	}
	pot.playerAddList(url, playlistExpandMode);
}


string _FormatDate(string date)
{
	// Thu, 04 Sep 2025 21:34:00 GMT -> 20250904
	// not consider time zone
	string year, month, day;
	array<string> arrMonth = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
	array<dictionary> match;
	if (tx.regExpParse(date, "(?i)\\w{3}, (\\d{2}) (\\w{3}) (\\d{4})\\b", match, 0) >= 0)
	{
		day = string(match[1]["str"]);
		month = string(match[2]["str"]);
		year = string(match[3]["str"]);
		month = formatInt(tx.findI(arrMonth, month) + 1);
		if (month.length() == 1) month = "0" + month;
		if (day.length() == 1) day = "0" + day;
		return year + "-" + month + "-" + day;
	}
	return "";
}


string _ReviseDate(string date)
{
	if (date.length() != 8) return date;
	string outDate = HostRegExpParse(date, "^(\\d+)$");
	if (outDate.length() != 8) return date;
	outDate = outDate.substr(0, 4) + "-" + outDate.substr(4, 2) + "-" + outDate.substr(6, 2);
	return outDate;
}


bool _IsGeneric(string extractor)
{
	if (tx.findRegExp(extractor, "(?i)(generic|html5)") == 0)
	{
		return true;
	}
	return false;
}

string _GetUrlDomain(string url)
{
	string domain;
	url.MakeLower();
	string _url = HostRegExpParse(url, "^https?://([^/?#]+)");
	if (_url.empty()) _url = url;
	int pos = _url.findLast(":");
	if (pos > 0) _url = _url.Left(pos);	// Remove port numbers
	if (!HostRegExpParse(_url, "^[\\d.]+$", {}))	// Exclude IPv4 address
	{
		if (domain.find(":") < 0)	// Exclude IPv6 addresses
		{
			array<dictionary> match;
			if (HostRegExpParse(_url, "([^.]+\\.)?([^.]+)\\.([^.]+)$", match))
			{
				string s1 = string(match[1]["first"]);
				string s2 = string(match[2]["first"]);
				string s3 = string(match[3]["first"]);
				if (s3.length() == 2)	// country code top level domain
				{
					if (s2.length() < 4)
					{
						if (!s1.empty() && s1 != "www.")
						{
							// Get the domain name up to 3rd level
							domain = s1 + s2 + "." + s3;
						}
					}
				}
				if (domain.empty())
				{
					// In most cases, get the domain name up to 2nd level
					domain = s2 + "." + s3;
				}
			}
		}
	}
	return domain;
}


string _ReviseWebString(string desc)
{
	desc.replace("\\r\\n", "\n");
	desc.replace("\\n", "\n");
	
	// Remove the top LF
	int lfPos = desc.find("\n");
	if (lfPos >= 0 && lfPos < 4) desc.erase(lfPos, 1);
	
	if (cfg.getInt("FORMAT", "title_multi_lines") != 1)
	{
		desc.replace("\n", " ");
	}
	//desc.replace("+", " ");
	
	desc = tx.decodeEntityRefs(desc);
	desc = tx.decodeNumericCharRefs(desc);
	desc = tx.decodeUTF16BE(desc);
	
	return desc;
}


bool _MatchAutoSubLangs(string code)
{
	if (code.empty()) return false;
	
	for (uint i = 0; i < cfg.autoSubLangs.length(); i++)
	{
		string findCode = cfg.autoSubLangs[i];
		findCode = tx.escapeReg(findCode);
		if (tx.findRegExp(code, "(?i)^" + findCode + "\\b") >= 0)
		{
			// If findCode is "zh", both "zh-Hans" and "zh-Hant" are matched.
			return true;
		}
	}
	return false;
}

bool _SelectAutoSub(string code, array<dictionary> &subtitleList)
{
	bool match = false;
	
	int pos = tx.findI(code, "-orig");
	if (pos > 0) {
		// original language of contents
		match = true;
	}
	else
	{
		if (_MatchAutoSubLangs(code))
		{
			match = true;
		}
	}
	
	if (!match) return false;
	
	// check overlapping
	for (int i = 0; i < int(subtitleList.length()); i++)
	{
		string existCode = string(subtitleList[i]["langCode"]);
		{
			if (code == existCode) return false;
			if (code + "-orig" == existCode) return false;
			if (code == existCode + "-orig")
			{
				string kind = string(subtitleList[i]["kind"]);
				if (kind == "asr")
				{
					subtitleList.removeAt(i);
					i--; continue;
				}
				else
				{
					return false;
				}
			}
		}
	}
	
	return true;
}


string _SupposeLangName(string note)
{
	// only for YouTube
	// Return true if note is possible to be a language name
	
	if (false)
	{
		// This is not available for some languages such as Polish.
		note = tx.omitDecimal(note, ",");
		if (!note.empty())
		{
			if (!HostRegExpParse(note, "^[a-z0-9([<]", {}))
			{
				if (!HostRegExpParse(note, "^[A-Z][A-Z0-9]", {}))
				{
					if (!HostRegExpParse(note, "\\w{20}", {}))
					{
						return note;
					}
				}
			}
		}
	}
	else
	{
		array<string> qualities = {"low", "medium", "large"};
		array<string> words = tx.trimSplit(note, ",");
		if (words.length() > 2)
		{
//HostPrintUTF8("Menu Word: " + words[1]);
			if (qualities.find(words[1]) >= 0)
			{
				return words[0];
			}
		}
	}
	
	return "";
}


bool _HideDubbed(string audioCode, string va, bool isDefault)
{
	// only for Youtube bubbed format
	
	int dubbedFilter = cfg.getInt("YOUTUBE", "dubbed_filter");
	
	if (dubbedFilter == 1)
	{
		if (va == "va" || va == "a")
		{
			if (audioCode.empty())
			{
				return true;
			}
			else if (!isDefault)
			{
				if (!_MatchAutoSubLangs(audioCode))
				{
					return true;
				}
			}
		}
	}
	else if (dubbedFilter == 2)
	{
		if (va == "va")
		{
			if (!isDefault || audioCode.empty())
			{
				return true;
			}
		}
	}
	
	return false;
}


void _FillAudioName(array<dictionary> &QualityList, string audioCode, string audioName)
{
	// only for Youtube bubbed format
	
	if (@QualityList is null) return;
	
	if (!audioCode.empty() && !audioName.empty())
	{
		for (uint i = 0; i < QualityList.length(); i++)
		{
			if (string(QualityList[i]["audioCode"]) == audioCode)
			{
				if (string(QualityList[i]["audioName"]).empty())
				{
					QualityList[i]["audioName"] = audioName;
				}
			}
		}
	}
}


bool _IsDuplicateAudioLang(array<dictionary> &QualityList, string audioCode)
{
	if (@QualityList is null) return false;
	
	for (int i = QualityList.length() - 1; i >= 0; i--)
	{
		if (string(QualityList[i]["va"]) == "a")
		{
			if (string(QualityList[i]["audioCode"]) == audioCode)
			{
				return true;
			}
		}
	}
	return false;
}


void _OrganizeDubbedFormat(array<dictionary> &QualityList)
{
	// only for Youtube bubbed format
	
	if (@QualityList is null) return;
	int removeDuplicateQuality = cfg.getInt("FORMAT", "remove_duplicate_quality");
	
	for (int i = 0; i < int(QualityList.length()); i++)
	{
		string va1 = string(QualityList[i]["va"]);
		
		if (va1 == "va" || va1 == "a")
		{
			string code1 = string(QualityList[i]["audioCode"]);
			string name1 = string(QualityList[i]["audioName"]);
			
			if (!code1.empty() && name1.empty())
			{
				// Fill missing audioName
				for (int j = 0; j < int(QualityList.length()); j++)
				{
					if (j == i) continue;
					
					string code2 = string(QualityList[j]["audioCode"]);
					if (code2 == code1)
					{
						string name2 = string(QualityList[j]["audioName"]);
						if (!name2.empty())
						{
							name1 = name2;
							break;
						}
					}
				}
				if (!name1.empty())
				{
					QualityList[i]["audioName"] = name1;
				}
				else
				{
					QualityList[i]["audioName"] = code1;
				}
			}
			
			if (removeDuplicateQuality == 1)
			{
				if (code1.empty())
				{
					QualityList.removeAt(i);
					i--; continue;
				}
				else
				{
					// Remove duplicate audio with the same language
					if (va1 == "a")
					{
						for (int j = i + 1; j < int(QualityList.length()); j++)
						{
							string va2 = string(QualityList[j]["va"]);
							if (va2 == "a")
							{
								string code2 = string(QualityList[j]["audioCode"]);
								if (code1 == code2)
								{
									QualityList.removeAt(j);
									j--; continue;
								}
							}
						}
					}
				}
			}
			
			bool audioIsDefault1 = bool(QualityList[i]["audioIsDefault"]);
			if (_HideDubbed(code1, va1, audioIsDefault1))
			{
				QualityList.removeAt(i);
				i--; continue;
			}
		}
	}
}


void _FillVR(array<dictionary> &QualityList, int type3D)
{
	if (@QualityList is null) return;
	
	for (uint i = 0; i < QualityList.length(); i++)
	{
		dictionary @Quality = QualityList[i];
		
		string va = string(Quality["va"]);
		if (va == "v" || va == "va")
		{
			if (!bool(Quality["is360"]))
			{
				Quality["is360"] = true;
			}
			if (type3D > 0)
			{
				if (int(Quality["type3D"]) == 0)
				{
					Quality["type3D"] = type3D;
				}
			}
		}
	}
}


bool __IsQualityDuplicate(dictionary quality1, dictionary quality2)
{
	array<string> keys = {
		"quality",
		"format",
		"fps",
		"dynamicRange",
		//"isHDR",
		//"is360",
		//"type3D",
		"audioCode"
	};
	
	for (uint j = 0; j < keys.length(); j++)
	{
		string key = keys[j];
		if (key.empty()) break;
		
		if (quality1.exists(key) != quality2.exists(key)) return false;
		
		if (quality1.exists(key))
		{
			string sVal1 = string(quality1[key]);
			string sVal2 = string(quality2[key]);
			if (sVal1.empty() != sVal2.empty()) return false;
			
			if (!sVal1.empty())
			{
				if (sVal1 != sVal2)
				{
					if (key == "quality")
					{
						// If the difference of bitrate is small, two audio qualities are considered the same.
						if (sVal1.Right(1) == "K" && sVal2.Right(1) == "K")
						{
							float fVal1 = parseFloat(sVal1);
							float fVal2 = parseFloat(sVal2);
							float d = fVal1 - fVal2;
							if (d < 0) d *= -1;
							if (d > 40) return false;
						}
						else
						{
							return false;
						}
					}
					else
					{
						return false;
					}
				}
			}
			else
			{
				float fVal1 = float(quality1[key]);
				float fVal2 = float(quality2[key]);
				if (fVal1 != fVal2) return false;
			}
		}
	}
	
	return true;
}


bool _IsQualityDuplicate(dictionary Quality, array<dictionary> &QualityList)
{
	if (@QualityList is null) return false;
	
	for (int i = QualityList.length() - 1; i >= 0; i--)
	{
		if (__IsQualityDuplicate(Quality, QualityList[i])) return true;
	}
	return false;
}


int _TitleChannelMode(string url)
{
	int mode = cfg.getInt("FORMAT", "title_channel_standard");
	if (mode < 0 || mode > 2) mode = 0;
	string domain = _GetUrlDomain(url);
	
	string data = cfg.getStr("FORMAT", "title_channel_each");
	data.MakeLower();
	array<string> arrData = tx.trimSplit(data, ",");
	
	for (uint i = 0; i < arrData.length(); i++)
	{
		array<string> item = tx.trimSplit(arrData[i], ":");
		if (item.length() == 2)
		{
			string _domain = item[0];
			if (domain.find(_domain) >= 0)
			{
				int _mode = parseInt(item[1]);
				if (_mode >= 0 && _mode <= 2)
				{
					mode = _mode;
					break;
				}
			}
		}
	}
	return mode;
}


bool _CheckProtocol(string protocol)
{
	if (protocol.Left(4) == "http") return false;
	if (protocol.Left(4) == "m3u8") return false;
	//if (protocol == "fc2_live") return false;
	return true;
}


int _CheckM3u8Hls(string url)
{
	string data = http.getContent(url, 3, 63);
	if (!data.empty())
	{
		if (data.find("\n#EXT-X-") >= 0)
		{
			return 1;	// HLS
		}
		if (data.findFirstNotOf("\r\n") >= 0)
		{
			return 0;	// non-HLS possibly
		}
	}
	return -1;	// Potential HLS
}


bool _CheckRadioServer(string httpHead)
{
	if (!httpHead.empty())
	{
		string title = http.getDataField(httpHead, "icy-name");
		if (!title.empty()) return true;
		string server = http.getDataField(httpHead, "Server");
		if (tx.findI(server, "icecast") >= 0) return true;
	}
	return false;
}

bool _GetRadioInfo(dictionary &inout MetaData, string httpHead, string url)
{
	if (httpHead.empty()) return false;
	
	string server = http.getDataField(httpHead, "Server");
	if (tx.findI(server, "icecast") >= 0)
	{
		server = "IcecastCh";
	}
	else
	{
		server = "ShoutcastCh";
	}
	
	if (server == "IcecastCh")
	{
		// XSPF metadata for icecast
		string url2 = url;
		if (url2.Right(1) == "/") url2.erase(url2.length() - 1);
		url2 += ".xspf";
		string data = http.getContent(url2, 5, 2047);
		if (!data.empty())
		{
			data = HostRegExpParse(data, "<annotation>([^<]+)</annotation>");
			string title = http.getDataField(data, "Stream Title");
			if (!title.empty())
			{
				if (server.empty()) server = "IcecastCh";
				string _s;
				MetaData["playUrl"] = url;
				if ((!MetaData.get("title", _s)) || _s.empty())
				{
					title = _ReviseWebString(title);
					title = _CutOffString(title);
					MetaData["title"] = title;
					MetaData["author"] = title + " @" +server;
						// The station name is kept in the author field
				}
				string genre = http.getDataField(data, "Stream Genre");
				string desc = http.getDataField(data, "Stream Description");
				string content;
				if (!genre.empty()) content = "{" + genre + "}";
				if (!desc.empty()) content = (!content.empty() ? " " : "") + desc;
				if (!content.empty())
				{
					content = _ReviseWebString(content);
					MetaData["content"] = content;
				}
				int viewCount = parseInt(http.getDataField(data, "Current Listeners"));
				if (viewCount > 0)
				{
					MetaData["viewCount"] = viewCount;
				}
				if (cfg.getInt("TARGET", "radio_thumbnail") == 1)
				{
					MetaData["thumbnail"] = _GetRadioThumb("icecast");
				}
				return true;
			}
		}
		
		// url3: baseUrl + "/status-json.xsl"	// for Icecast
	}
	
	// Metadata from icy- header
	string title = http.getDataField(httpHead, "icy-name");
	if (!title.empty())
	{
		MetaData["playUrl"] = url;
		string _s;
		if ((!MetaData.get("title", _s)) || _s.empty())
		{
			title = _ReviseWebString(title);
			title = _CutOffString(title);
			MetaData["title"] = title;
			MetaData["author"] = title + " @" +server;
				// The station name is kept in the author field
		}
		string genre = http.getDataField(httpHead, "icy-genre");
		string desc = http.getDataField(httpHead, "icy-description");
		string content;
		if (!genre.empty()) content = "{" + genre + "}";
		if (!desc.empty()) content = (!content.empty() ? " " : "") + desc;
		if (!content.empty())
		{
			content = _ReviseWebString(content);
			MetaData["content"] = content;
		}
		int viewCount = parseInt(http.getDataField(httpHead, "icy-listeners"));
		if (viewCount > 0)
		{
			MetaData["viewCount"] = viewCount;
		}
		if (cfg.getInt("TARGET", "radio_thumbnail") == 1)
		{
			MetaData["thumbnail"] = _GetRadioThumb(server == "IcecastCh" ? "icecast" : "shoutcast");
		}
		return true;
	}
	
	return false;
}


void _SetFileInfo(dictionary &inout MetaData, string url, string httpHead, bool setThumb)
{
	MetaData["playUrl"] = url;
	
	string domain = _GetUrlDomain(url);
	if (!domain.empty()) MetaData["author"] = domain;
	
	string date = http.getDataField(httpHead, "Last-Modified");
	if (date.empty()) date = http.getDataField(httpHead, "Date");
	if (!date.empty())
	{
		date = _FormatDate(date);
		if (!date.empty()) MetaData["date"] = date;
	}
	
	if (setThumb)
	{
		MetaData["thumbnail"] = url;
	}
}


string _GetFileType(string httpHead)
{
	// Check if a real file exists on the server with Content-Length
	
	int contLen = parseInt(http.getDataField(httpHead, "Content-Length"));
	if (contLen > 100)
	{
		string contType = http.getDataField(httpHead, "Content-Type");
		if (!contType.empty())
		{
			if (tx.findI(contType, "image/") >= 0)
			{
				return "image";
			}
			else if (tx.findI(contType, "video/") >= 0)
			{
				array<string> arrVideo = {"mp4", "webm", "ogg", "mpeg"};
				if (tx.findI(arrVideo, contType.substr(6)) >= 0)
				{
					return "video";
				}
			}
			else if (tx.findI(contType, "audio/") >= 0)
			{
				array<string> arrAudio = {"mpeg", "aac", "aacp", "flac", "ogg", "opus", "webm", "wav", "x-wav"};
				if (tx.findI(arrAudio, contType.substr(6)) >= 0)
				{
					return "audio";
				}
			}
			else if (tx.findI(contType, "application/") >= 0)
			{
				// media containers
				if (tx.findI(contType, "/ogg") >= 0) return "audio";
				if (tx.findI(contType, "/mp4") >= 0) return "video/audio";
				if (tx.findI(contType, "/webm") >= 0) return "video/audio";
				if (tx.findI(contType, "/mxf") >= 0) return "video/audio";
			}
		}
	}
	return "";
}


string _ReviseCookie(string cookie)
{
	if (cookie.empty()) return "";
	cookie += "; ";
	
	array<string> attributes = {"Domain", "Path", "Secure", "Expires", "HttpOnly", "Max-Age", "SameSite", "Partitioned"};
	
	for (uint i = 0; i < attributes.length(); i++)
	{
		int pos = 0;
		while (true)
		{
			string str;
			pos = tx.findRegExp(cookie, "\\b" + attributes[i] + "\\b[^;]*; ", str, pos);
			if (pos >= 0)
			{
				cookie.erase(pos, str.length());
				continue;
			}
			break;
		}
	}
	
	if (cookie.Right(1) == " ") cookie = cookie.Left(cookie.length() - 1);
	if (cookie.Right(1) == ";") cookie = cookie.Left(cookie.length() - 1);
	cookie.replace("\"", "");
	
	return cookie;
}


string _SetRequestHeader(string url, JsonValue jFormat)
{
	string reqHeader;
	
	JsonValue jHeaders = jFormat["http_headers"];
	if (jHeaders.isObject())
	{
		string userAgent;
		jsn.getValueString(jHeaders, "User-Agent", userAgent);
		if (!userAgent.empty())
		{
			reqHeader += "User-Agent: " + userAgent + "\r\n";
			
			//HostSetUrlUserAgentHTTP(url, userAgent);
		}
		
		string referer;
		jsn.getValueString(jHeaders, "Referer", referer);
		if (!referer.empty())
		{
			reqHeader += "Referer: " + referer + "\r\n";
			
			// PP 260114 or later
			HostSetUrlRefererHTTP(url, referer);
		}
		
		string accept;
		jsn.getValueString(jHeaders, "Accept", accept);
		if (!accept.empty())
		{
			reqHeader += "Accept: " + accept + "\r\n";
		}
		
		string acceptLanguage;
		jsn.getValueString(jHeaders, "Accept-Language", acceptLanguage);
		if (!acceptLanguage.empty())
		{
			reqHeader += "Accept-Language: " + acceptLanguage + "\r\n";
		}
		
		string secFetchMode;
		jsn.getValueString(jHeaders, "Sec-Fetch-Mode", secFetchMode);
		if (!secFetchMode.empty())
		{
			reqHeader += "Sec-Fetch-Mode: " + secFetchMode + "\r\n";
		}
	}
	
	string cookie;
	jsn.getValueString(jFormat, "cookies", cookie);
	if (!cookie.empty())
	{
		cookie = _ReviseCookie(cookie);
		reqHeader += "Cookie: " + cookie + "\r\n";
		
		// PP 260114 or later
		HostSetUrlCookieHTTP(url, cookie);
	}
	
	/*
	// HostSetUrlHeaderHTTP is called in PlaylistParse
	if (!reqHeader.empty())
	{
		HostSetUrlHeaderHTTP(url, reqHeader);
	}
	*/
	
	return reqHeader;
}


bool _CheckLiveThrough(dictionary &MetaData, string url)
{
	if (bool(MetaData["liveThrough"]))
	{
		if (cfg.csl > 0)
		{
			HostPrintUTF8("[yt-dlp] YouTube Live was passed through according to the [youtube_live] setting. - " + tx.qt(url) +"\r\n");
		}
		return true;
	}
	return false;
}


string _PlayitemParseDirect(string inUrl, dictionary &MetaData, array<dictionary> &QualityList)
{
	string httpHead = http.getHeader(inUrl, 5);
	if (tx.findRegExp(httpHead, "(?i)HTTP/\\d\\.\\d 20\\d") >= 0)
	{
		string ext0 = _GetUrlExtension(inUrl);
		if (ext0 == "m3u8" || ext0 == "txt")
		{
			if (_CheckM3u8Hls(inUrl) == 0) return "";
		}
		
		// online files
		string fileType = _GetFileType(httpHead);
		if (!fileType.empty())
		{
			if (cfg.getInt("TARGET", "direct_file_info") == 1)
			{
				_SetFileInfo(MetaData, inUrl, httpHead, (fileType != "audio"));
				if (cfg.csl > 0)
				{
					HostPrintUTF8("[yt-dlp] Got metadata from a direct media file. - " + tx.qt(inUrl) + "\r\n\r\n");
				}
				return inUrl;
			}
			return "";
		}
		
		// online radio (shoutcast)
		if (_IsUrlSite(inUrl, "shoutcast"))
		{
			string outUrl = shoutpl.parse(inUrl, MetaData, QualityList, true);
			if (!outUrl.empty())
			{
				if (cfg.csl > 0)
				{
					HostPrintUTF8("\r\nStation: " + string(MetaData["title"]) + "\r\n");
					if (cfg.csl > 1 && @QualityList !is null)
					{
						for (uint i = 0; i < QualityList.length(); i++)
						{
							string serverName = string(QualityList[i]["format"]);
							string serverUrl = string(QualityList[i]["url"]);
							string msg = "Server: [" + serverName + "] " + serverUrl;
							HostPrintUTF8(msg);
						}
						HostPrintUTF8("\r\n");
					}
					HostPrintUTF8("[yt-dlp] Parsed Shoutcast playlist. - " + tx.qt(inUrl) + "\r\n\r\n");
				}
				if (cfg.getInt("TARGET", "radio_info") == 1)
				{
					_GetRadioInfo(MetaData, httpHead, outUrl);
				}
				return outUrl;
			}
		}
		
		// online radio
		if (cfg.getInt("TARGET", "radio_info") == 1)
		{
			if (_GetRadioInfo(MetaData, httpHead, inUrl))
			{
				if (cfg.csl > 0)
				{
					HostPrintUTF8("\r\nStation: " + string(MetaData["title"]) + "\r\n");
					HostPrintUTF8("[yt-dlp] Got metadata for a streaming radio. - " + tx.qt(inUrl) + "\r\n\r\n");
				}
				return inUrl;
			}
		}
		else
		{
			if (_CheckRadioServer(httpHead))
			{
				MetaData["playUrl"] = inUrl;
				if (cfg.csl > 0)
				{
					HostPrintUTF8("[yt-dlp] This URL is for a streaming radio. - " + tx.qt(inUrl) + "\r\n\r\n");
				}
				return inUrl;
			}
		}
	}
	
	return "";
}


dictionary _ParseMetaDataSimple(JsonValue &root, string imgUrl, bool toAlbum)
{
	dictionary MetaData = {};
	
	string webUrl;
	jsn.getValueString(root, "webpage_url", webUrl);
	if (webUrl.empty()) return {};
	string baseName;
	jsn.getValueString(root, "webpage_url_basename", baseName);
	if (baseName.empty()) return {};
	{
		// Remove parameter added by yt-dlp.
		int pos = webUrl.find("#__youtubedl");
		if (pos > 0) webUrl = webUrl.Left(pos);
	}
	MetaData["webUrl"] = webUrl;
	string ext2 = HostGetExtension(baseName);
	
	MetaData["url"] = webUrl;	// Can be changed to inUrl later
	
	string extractor;
	jsn.getValueString(root, "extractor_key", extractor);
	if (extractor.empty())
	{
		jsn.getValueString(root, "extractor", extractor);
		if (extractor.empty())
		{
			return {};
		}
	}
	MetaData["extractor"] = extractor;
	
	string ext;
	jsn.getValueString(root, "ext", ext);
	MetaData["fileExt"] = ext;
	
	bool isAudio = _IsExtType(ext, 0x100);
	MetaData["isAudio"] = isAudio;
	
	int playlistIdx;
	jsn.getValueInt(root, "playlist_index", playlistIdx);
	MetaData["playlistIndex"] = playlistIdx;
	
	int playlistCnt;
	jsn.getValueInt(root, "playlist_count", playlistCnt);
	MetaData["playlistCount"] = playlistCnt;
	
	string playlistTitle;
	jsn.getValueString(root, "playlist_title", playlistTitle);
	if (!playlistTitle.empty())
	{
		if (baseName != playlistTitle + ext2)
		{
			playlistTitle = _ReviseWebString(playlistTitle);
			playlistTitle = _CutOffString(playlistTitle);
		}
	}
	MetaData["playlistTitle"] = playlistTitle;
	
	string title;
	jsn.getValueString(root, "title", title);
	if (!title.empty())
	{
		title = _ReviseWebString(title);
		if (baseName != title + ext2)
		{
			// Consider title as empty if yt-dlp cannot get a substantial title.
			// Prevent PotPlayer from overwriting the edited title in the playlist panel.
			title = _CutOffString(title);
		}
	}
	MetaData["title"] = title;
	
	string duration;
	jsn.getValueString(root, "duration_string", duration);
	if (duration.empty())
	{
		int secDuration;
		jsn.getValueInt(root, "duration", secDuration);
		if (secDuration > 0)
		{
			duration = "0:" + secDuration;
			// Convert to format "hh:mm:ss" by adding "0:" to the top
		}
	}
	else
	{
		if (duration.find(":") < 0)
		{
			duration = "0:" + duration;
		}
	}
	MetaData["duration"] = duration;
	
	string thumb;
	jsn.getValueString(root, "thumbnail", thumb);
	if (thumb.empty())
	{
		JsonValue jThumbs = root["thumbnails"];
		if (jThumbs.isArray())
		{
			int n = jThumbs.size();
			if (n > 0)
			{
				JsonValue jThumbmax = jThumbs[n - 1];
				if (jThumbmax.isObject())
				{
					jsn.getValueString(jThumbmax, "url", thumb);
				}
			}
		}
		if (thumb.empty())
		{
			if (!imgUrl.empty())
			{
				thumb = imgUrl;
			}
			else if (isAudio && toAlbum && _IsGeneric(extractor))
			{
				if (cfg.getInt("FORMAT", "radio_thumbnail") == 1)
				{
					thumb = _GetRadioThumb();
				}
			}
		}
	}
	if (!thumb.empty())
	{
		thumb = _ReviseThumbnail(thumb);
	}
	MetaData["thumbnail"] = thumb;
	
	string author;
	jsn.getValueString(root, "channel", author);
	if (author.empty())
	{
		jsn.getValueString(root, "uploader", author);
		if (author.empty())
		{
			jsn.getValueString(root, "uploader_id", author);
			if (author.empty())
			{
				jsn.getValueString(root, "artist", author);
				if (author.empty())
				{
					jsn.getValueString(root, "creator", author);
				}
			}
		}
	}
	if (!author.empty())
	{
		author = _ReviseWebString(author);
		if (author.Left(1) == "@")	// youtube
		{
			author = author.substr(1);
			author.replace("_", " ");
		}
	}
	MetaData["author"] = author + " @" + extractor;
	
	return MetaData;
}


dictionary _ParseMetaData(JsonValue &root, string inUrl, string imgUrl, bool toAlbum)
{
	JsonValue jFormats = root["formats"];
	if (!jFormats.isArray() || jFormats.size() == 0)
	{
		// For a simple playlist (fast)
		return _ParseMetaDataSimple(root, imgUrl, toAlbum);
	}
	
	dictionary MetaData = {};
	
	string version;
	JsonValue jVersion = root["_version"];
	if (jVersion.isObject())
	{
		jsn.getValueString(jVersion, "version", version);
	}
	if (version.empty())
	{
		HostPrintUTF8("[yt-dlp] CRITICAL ERROR! No version info.\r\n");
		ytd.criticalError(); return {};
	}
	
	string extractor;
	jsn.getValueString(root, "extractor_key", extractor);
	if (extractor.empty())
	{
		jsn.getValueString(root, "extractor", extractor);
		if (extractor.empty())
		{
			HostPrintUTF8("[yt-dlp] CRITICAL ERROR! No extractor.\r\n");
			ytd.criticalError(); return {};
		}
	}
	MetaData["extractor"] = extractor;
	bool isGeneric = _IsGeneric(extractor);
	
	string webUrl, baseName;
	jsn.getValueString(root, "webpage_url", webUrl);
	jsn.getValueString(root, "webpage_url_basename", baseName);
	if (webUrl.empty() || baseName.empty())
	{
		HostPrintUTF8("[yt-dlp] CRITICAL ERROR! No webpage URL.\r\n");
		ytd.criticalError(); return {};
	}
	{
		// Remove parameter added by yt-dlp.
		int pos = webUrl.find("#__youtubedl");
		if (pos > 0) webUrl = webUrl.Left(pos);
	}
	string ext2 = HostGetExtension(baseName);	// include the top dot
	MetaData["webUrl"] = webUrl;
	MetaData["baseName"] = baseName;
	
	MetaData["url"] = webUrl;	// Can be changed to inUrl later
	
	string author;
	jsn.getValueString(root, "channel", author);
	if (author.empty())
	{
		jsn.getValueString(root, "uploader", author);
		if (author.empty())
		{
			jsn.getValueString(root, "uploader_id", author);
			if (author.empty())
			{
				jsn.getValueString(root, "artist", author);
				if (author.empty())
				{
					jsn.getValueString(root, "creator", author);
				}
			}
		}
	}
	if (!author.empty())
	{
		author = _ReviseWebString(author);
		if (author.Left(1) == "@")	// youtube
		{
			author = author.substr(1);
			author.replace("_", " ");
		}
	}
	MetaData["originalAuthor"] = author;
	
	int titleChannelMode = _TitleChannelMode(inUrl);
	string titleChannelSepa = cfg.getStr("FORMAT", "title_channel_separator");
	
	int playlistIdx;
	jsn.getValueInt(root, "playlist_index", playlistIdx);
	MetaData["playlistIndex"] = playlistIdx;
	
	int playlistCnt;
	jsn.getValueInt(root, "playlist_count", playlistCnt);
	MetaData["playlistCount"] = playlistCnt;
	
	string playlistTitle;
	jsn.getValueString(root, "playlist_title", playlistTitle);
	if (!playlistTitle.empty())
	{
		if (baseName == playlistTitle + ext2)
		{
			playlistTitle = "";
		}
		else
		{
			playlistTitle = _ReviseWebString(playlistTitle);
			
			if (!author.empty() && titleChannelMode == 2)
			{
				if (_YoutubeChannel(inUrl) > 0 || _CheckBiliPart(webUrl) > 0)
				{
					if (playlistTitle.find(author) < 0)
					{
						playlistTitle = author + titleChannelSepa + playlistTitle;
					}
				}
			}
			
			playlistTitle = _CutOffString(playlistTitle);
		}
	}
	MetaData["playlistTitle"] = playlistTitle;
	
	bool isLive;
	jsn.getValueBool(root, "is_live", isLive);
	if (!isLive)
	{
		string liveStatus;
		jsn.getValueString(root, "live_status", liveStatus);
		if (liveStatus == "is_live") isLive = true;
		if (!isLive)
		{
			int concurrentViewCount;
			jsn.getValueInt(root, "concurrent_view_count", concurrentViewCount);
			if (concurrentViewCount > 0) isLive = true;
		}
	}
	MetaData["isLive"] = isLive;
	
	string chatUrl;
	if (isLive && playlistIdx == 0)
	{
		if (tx.findI(extractor, "youtube") >= 0)
		{
			if (cfg.getInt("YOUTUBE", "youtube_live") != 1)
			{
				// Pass through YouTube Live
				MetaData["liveThrough"] = true;
				
				return MetaData;
			}
		}
		
		// support live chat
		if (cfg.getInt("TARGET", "live_chat") == 1)
		{
			chatUrl = _GetChatUrl(inUrl);
		}
	}
	MetaData["chatUrl"] = chatUrl;
	
	string ext;
	jsn.getValueString(root, "ext", ext);
	MetaData["fileExt"] = ext;
	
	bool isAudio = _IsExtType(ext, 0x100);
	MetaData["isAudio"] = isAudio;
	
	string title;
	jsn.getValueString(root, "title", title);
	if (baseName == title + ext2)
	{
		title = "";
		// MetaData["title"] is empty if yt-dlp cannot get a substantial title.
		// Prevent potplayer from overwriting the edited title in the playlist panel.
	}
	bool isShoutcast = false;
	if (tx.findI(title, "Shoutcast Server") == 0)
	{
		isShoutcast = true;
		title = "";
	}
	if (!title.empty())
	{
		title = _ReviseWebString(title);
		if (cfg.getInt("FORMAT", "title_alt_detail") == 1)
		{
			string altTitle;
			jsn.getValueString(root, "alt_title", altTitle);
			if (!altTitle.empty())
			{
				altTitle = _ReviseWebString(altTitle);
				if (altTitle.find(title) >= 0)
				{
					title = altTitle;
				}
			}
		}
	}
	MetaData["originalTitle"] = title;
	
	string duration;
	jsn.getValueString(root, "duration_string", duration);
	if (duration.empty())
	{
		int secDuration;
		jsn.getValueInt(root, "duration", secDuration);
		if (secDuration > 0)
		{
			duration = formatInt(secDuration);
		}
	}
	if (!duration.empty())
	{
		if (duration.find(":") < 0)
		{
			// Convert the format to "hh:mm:ss" by adding "0:" to the top
			duration = "0:" + duration;
		}
	}
	MetaData["duration"] = duration;
	
	string thumb;
	jsn.getValueString(root, "thumbnail", thumb);
	if (thumb.empty())
	{
		JsonValue jThumbs = root["thumbnails"];
		if (jThumbs.isArray())
		{
			int maxIdx = jThumbs.size() - 1;
			if (maxIdx >= 0)
			{
				jsn.getValueString(jThumbs[maxIdx], "url", thumb);
			}
		}
		if (thumb.empty())
		{
			if (!imgUrl.empty())
			{
				thumb = imgUrl;
			}
			else if (isLive && tx.findI(extractor, "TwitchVod") == 0)
			{
				// Remove the --live-from-start option
				thumb = ytd.getThumbnail(inUrl);
			}
			else if (isAudio && toAlbum && _IsGeneric(extractor))
			{
				if (cfg.getInt("FORMAT", "radio_thumbnail") == 1)
				{
					thumb = _GetRadioThumb();
				}
			}
		}
	}
	if (!thumb.empty())
	{
		thumb = _ReviseThumbnail(thumb);
	}
	MetaData["thumbnail"] = thumb;
	
	string date;
	jsn.getValueString(root, "upload_date", date);
	if (!date.empty())
	{
		date = _ReviseDate(date);
	}
	MetaData["date"] = date;
	
	string desc;
	jsn.getValueString(root, "description", desc);
	if (!desc.empty())
	{
		desc = _ReviseWebString(desc);
	}
	
	string title2 = title;
	{
		if (!title2.empty())
		{
			if (tx.findI(extractor, "facebook") >= 0)	// facebook
			{
				// Remove the count of playback/reactions/share in the title top
				int pos = title2.findFirst(" | ");
				if (pos >= 0) title2 = title2.substr(pos + 3);
				
				// Remove the uploader's name
				pos = title2.findLast(" | ");
				if (pos >= 0) title2 = title2.Left(pos);
			}
			
			if (!desc.empty() && tx.isCutOffString(title2, desc))
			{
				title2 = desc;
			}
			else
			{
				string title3 = title2;
				string curTime;	// current time
				int pos;
				
				pos = tx.findRegExp(title3, "\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}", curTime);
				if (pos >= 0)
				{
					title3.erase(pos, curTime.length());
				}
				else
				{
					pos = tx.findRegExp(title3, "\\d{4}-\\d{2}-\\d{2}", curTime);
					if (pos >= 0)
					{
						title3.erase(pos, curTime.length());
					}
				}
				
				if (!author.empty())
				{
					pos = title3.find(author);
					if (pos >= 0)
					{
						title3.erase(pos, author.length());
					}
				}
				
				pos = tx.findI(title3, extractor);
				if (pos >= 0)
				{
					title3.erase(pos, extractor.length());
				}
				
				pos = tx.findI(title3, "live");
				if (pos >= 0)
				{
					title3.erase(pos, 4);
				}
				
				pos = tx.findI(title3, "Video by ");
				if (pos >= 0)
				{
					title3.erase(pos, 9);
				}
				
				title3.replace(" ", "");
				title3.replace("-", "");
				title3.replace("/", "");
				title3.replace("@", "");
				title3.replace("(", "");
				title3.replace(")", "");
				title3.replace("[", "");
				title3.replace("]", "");
				
				if (title3.empty())
				{
					title2 = "";
					if (!desc.empty())
					{
						title2 = desc;
					}
					else if (!author.empty())
					{
						title2 = author;
						if (!isGeneric)
						{
							title2 += " (" + extractor + ")";
						}
					}
					else if (!isGeneric)
					{
						title2 = extractor;
					}
					
					if (!curTime.empty())
					{
						title2 += " " + curTime;
					}
					else if (!date.empty())
					{
						title2 += " " + date;
					}
				}
			}
		}
		
		if (tx.isSameDesc(title2, desc))
		{
			desc = "";	// Delete duplicate desc data
		}
		
		if (isLive && !author.empty())
		{
			if (title2.find(author) < 0)
			{
				if (titleChannelMode == 1 || titleChannelMode == 2)
				{
					title2 = author + (title2.find("\n") > 0 ? "\n" : titleChannelSepa) + title2;
				}
			}
			string livePrefix = cfg.getStr("FORMAT", "title_live_prefix");
			title2 = livePrefix + title2;
		}
		else
		{
			if (title2.find(author) < 0)
			{
				if (titleChannelMode == 2)
				{
					title2 = author + (title2.find("\n") > 0 ? "\n" : titleChannelSepa) + title2;
				}
			}
		}
		
		if (!title2.empty())
		{
			title2 = _CutOffString(title2);
		}
	}
	MetaData["title"] = title2;
	MetaData["content"] = desc;
	
	string author2 = author;	// substantial author
	if (author2.empty())
	{
		if (isGeneric)
		{
			string urlDomain;
			jsn.getValueString(root, "webpage_url_domain", urlDomain);
			if (!urlDomain.empty())
			{
				author2 = _GetUrlDomain(urlDomain);
			}
		}
	}
	if (isGeneric)
	{
		if (isShoutcast)
		{
			author2 += (!author.empty() ? " " : "") + "@ShoutcastCh";
		}
	}
	else
	{
		author2 += (!author.empty() ? " " : "") + "@" + extractor;
	}
	MetaData["author"] = author2;
	
	int viewCount;
	jsn.getValueInt(root, "view_count", viewCount);
	if (viewCount == 0)
	{
		int concurrentViewCount;
		jsn.getValueInt(root, "concurrent_view_count", concurrentViewCount);
		if (concurrentViewCount > 0)
		{
			viewCount = concurrentViewCount;
		}
	}
	if (viewCount > 0) MetaData["viewCount"] = formatInt(viewCount);
	
	int likeCount;
	jsn.getValueInt(root, "like_count", likeCount);
	if (likeCount > 0) MetaData["likeCount"] = formatInt(likeCount);
	
	return MetaData;
}


dictionary _ParseMetaData(string json, string inUrl, string imgUrl, bool toAlbum)
{
	JsonReader reader;
	JsonValue root;
	if (reader.parse(json, root) && root.isObject())
	{
		dictionary MetaData = _ParseMetaData(root, inUrl, imgUrl, toAlbum);
		return MetaData;
	}
	return {};
}


string _PlayitemParse(const string &in path, dictionary &MetaData, array<dictionary> &QualityList, uint startTime)
{
	string inUrl = _ReviseUrl(path);
	string outUrl;
	
	int doubleTrigger = hist.getDoubleTrigger(path, false, startTime);
	if (doubleTrigger == 1)
	{
		if (cfg.csl > 0)
		{
			HostPrintUTF8("\r\n[yt-dlp] Double Trigger - " + tx.qt(inUrl) + "\r\n");
		}
	}
	
	while (true)
	{
		int prevIdx = hist.findPrev(path, false, startTime, 0);
		if (prevIdx < 0)
		{
			break;
		}
		
		if (doubleTrigger > 0)
		{
			uint prevStartTime = uint(hist.list[prevIdx]["startTime"]);
			if (startTime >= prevStartTime && startTime - prevStartTime  >= DOUBLE_TRIGGER_INTERVAL_2)
			{
				hist.blockSaveCache(path, false, startTime);
				break;
			}
		}
		
		// previous processing is still working
//HostPrintUTF8("waiting...");
		HostIncTimeOut(3000);
		HostSleep(3000);
		
		if (hist.checkCancel(path, false, startTime, false) > 0) return "";
	}
	
	MetaData = cache.getItem(inUrl, QualityList);
	if (!MetaData.empty())
	{
		if (_CheckLiveThrough(MetaData, inUrl))
		{
			return "";
		}
		
		outUrl = string(MetaData["playUrl"]);
		
		if (doubleTrigger <= 0)
		{
			if (cfg.csl > 0)
			{
				HostPrintUTF8("[yt-dlp] Used cache to play - " + tx.qt(inUrl) + "\r\n");
			}
			HostSleep(DOUBLE_TRIGGER_INTERVAL_1);	// for waiting Double Trigger
			return outUrl;
		}
		
		if (int(MetaData["playlistSelfCount"]) > 0)
		{
			if (doubleTrigger == 1)
			{
				if (cfg.csl > 0)
				{
					HostPrintUTF8("[yt-dlp] Used cache to play - " + tx.qt(inUrl) + "\r\n");
					HostPrintUTF8("[yt-dlp] Expanding playlist... - " + tx.qt(inUrl) + "\r\n");
				}
				return outUrl;
			}
			else if (doubleTrigger == 2)
			{
				if (cfg.csl > 0)
				{
					HostPrintUTF8("\r\n[yt-dlp] Delayed Double Trigger: Expanding playlist via Force Reload... - " + tx.qt(inUrl) + "\r\n");
				}
			}
		}
		else if (doubleTrigger == 2)
		{
			if (cfg.csl > 0)
			{
				HostPrintUTF8("[yt-dlp] Used cache to play - " + tx.qt(inUrl) + "\r\n");
			}
			return outUrl;
		}
		
		uint cacheTime = cache.getTime(inUrl, "MetaData");
		if (cacheTime > startTime - DOUBLE_TRIGGER_INTERVAL_2)
		{
			// new cache
			return outUrl;
		}
		
		// reload without old cache
		MetaData.deleteAll();
		QualityList.resize(0);
		outUrl = "";
		cache.remove(inUrl, "MetaData");
	}
	
	string imgUrl = "";
	string json = cache.getJson(inUrl, imgUrl);
	if (!json.empty())
	{
		if (doubleTrigger == 2 || doubleTrigger == 1 && jsn.getDirectValueInt(json, "playlist_index") == 0)
		{
			uint cacheTime = cache.getTime(inUrl, "json");
			if (cacheTime < startTime - DOUBLE_TRIGGER_INTERVAL_2)
			{
				json = "";
				cache.remove(inUrl, "json");
			}
		}
	}
	
	if (!json.empty())
	{
		if (cfg.csl > 0)
		{
			HostPrintUTF8("[yt-dlp] Used temporary JSON cache to play - " + tx.qt(inUrl) + "\r\n");
		}
	}
	else
	{
		outUrl = _PlayitemParseDirect(inUrl, MetaData, QualityList);
		if (!outUrl.empty())
		{
//HostPrintUTF8("direct");
			return outUrl;
		}
		
		// Execute yt-dlp
		array<string> jsonList = ytd.exec1(inUrl, 0);
		if (jsonList.length() == 0) return "";
		json = jsonList[0];
		
		int cancelMode = hist.checkCancel(path, false, startTime);
		if (cancelMode == 2) return "";
		cache.addJson(inUrl, json);
		if (cancelMode == 1) return "";
	}
	
//HostPrintUTF8("json parsing start");
	JsonReader reader;
	JsonValue root;
	if (!reader.parse(json, root) || !root.isObject())
	{
		HostPrintUTF8("[yt-dlp] CRITICAL ERROR! JSON data corrupted.\r\n");
		ytd.criticalError(); return "";
	}
	
	MetaData = _ParseMetaData(root, inUrl, imgUrl, false);
	if (MetaData.empty()) return "";
	
	MetaData["url"] = inUrl;
	
	if (_CheckLiveThrough(MetaData, inUrl))
	{
		if (hist.checkCancel(path, false, startTime) == 2) return "";
		cache.addItem(inUrl, MetaData, {});
		return "";
	}
	
	bool isYoutube = _IsUrlSite(inUrl, "youtube");
	
	if (int(MetaData["playlistIndex"]) > 0)
	{
		// playlist item
		
		if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] This URL is for a playlist.\r\n");
		
		MetaData["title"] = string(MetaData["playlistTitle"]);
		
		MetaData["duration"] = "";
		
		uint playlistSelfCnt = uint(MetaData["playlistCount"]);
		MetaData["playlistSelfCount"] = playlistSelfCnt;
		
		string author = string(MetaData["author"]);
		string extractor = string(MetaData["extractor"]);
		string playlistNote = _GetPlaylistNote(inUrl, playlistSelfCnt, author, extractor);
		if (!playlistNote.empty())
		{
			MetaData["playlistNote"] = playlistNote;
			MetaData["author"] = playlistNote;
			MetaData["originalAuthor"] = author;
		}
		
		string thumb = "";
		if (isYoutube || _IsPotentialBiliPart(inUrl))
		{
			thumb = string(MetaData["thumbnail"]);
		}
		else if (playlistSelfCnt == 1)
		{
			thumb = string(MetaData["thumbnail"]);
			// This is the thumbnail of the LAST item in the playlist except YouTube.
		}
		else
		{
			thumb = ytd.getThumbnail(inUrl);
		}
		if (!thumb.empty())
		{
			thumb = _ReviseThumbnail(thumb);
			outUrl = thumb;
		}
		else
		{
			thumb = _GetPlaylistThumb();
			outUrl = inUrl;
		}
		MetaData["thumbnail"] = thumb;
		
		MetaData["playUrl"] = outUrl;
		
		int cancelMode = hist.checkCancel(path, false, startTime);
		if (cancelMode == 2) return "";
		cache.addItem(inUrl, MetaData, {});
		if (cancelMode == 1) return "";
		
		return outUrl;
	}
	
	if (cfg.csl > 0)
	{
		string msg;
		string title = string(MetaData["title"]);
		msg += "\r\nTitle: " + title + "\r\n";
		if (false && cfg.csl > 1)
		{
			string desc = string(MetaData["content"]);
			msg += "\r\nDescription Start >>>>>>>>>>>>>>>>\r\n\r\n";
			msg += desc;
			msg += "\r\n\r\n<<<<<<<<<<<<<< Description End\r\n";
		}
		msg += "\r\n";
		HostPrintUTF8(msg);
	}
	
	string extractor = string(MetaData["extractor"]);
	
	bool isLive = bool(MetaData["isLive"]);
	string ext = string(MetaData["fileExt"]);
	
	int secDuration;
	jsn.getValueInt(root, "duration", secDuration);
	
	
	string reqHeader;
	string resolution;
	
	// Exist a format in the top level of root directly
	jsn.getValueString(root, "url", outUrl);
	if (!outUrl.empty())
	{
		string protocol;
		jsn.getValueString(root, "protocol", protocol);
		if (!protocol.empty() && _CheckProtocol(protocol))
		{
			outUrl = "";
		}
		else
		{
			reqHeader = _SetRequestHeader(outUrl, root);
			jsn.getValueString(root, "resolution", resolution);
		}
	}
	
	JsonValue jFormats = root["formats"];
	if (!jFormats.isArray() || jFormats.size() == 0)
	{
		// Do not treat it as an error.
		// For getting uploader(website) or thumbnail or upload date.
		if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] The \"formats\" entry is not found.\r\n");
	}
	
	// for VR - only Equirectangular of VR360
	// Other VR formats (such as EAC) are not available.
	bool is360 = false;
	int type3D = 0;
	
	// for auto-dubbed tracks
	bool multiLang = false;
	string prevAudioCode;
	
	uint vaCount = 0;
	uint vCount = 0;
	uint aCount = 0;
	string vaOutUrl, vOutUrl, aOutUrl;
	
	int reduceFormats = cfg.getInt("FORMAT", "reduce_formats");
	
	bool rev = (reduceFormats == 2);
	for (int i = rev ? 0 : (jFormats.size() - 1); rev ? (i < jFormats.size()) : (i >= 0) ; rev ? i++ : i--)
	{
		// !rev: for (int i = jFormats.size() - 1; i >= 0 ; i--)
		// rev; for (int i = 0; i < jFormats.size() ; i++)
		
		JsonValue jFormat = jFormats[i];
		
		string protocol;
		jsn.getValueString(jFormat, "protocol", protocol);
		if (_CheckProtocol(protocol))
		{
			continue;
		}
		
		string fmtUrl;
		jsn.getValueString(jFormat, "url", fmtUrl);
//HostPrintUTF8("fmtUrl: " + fmtUrl);
		if (fmtUrl.empty()) continue;
		
		string fmtExt;
		jsn.getValueString(jFormat, "ext", fmtExt);
		string vExt;
		jsn.getValueString(jFormat, "video_ext", vExt);
		string aExt;
		jsn.getValueString(jFormat, "audio_ext", aExt);
		if (fmtExt.empty() || vExt.empty() || aExt.empty())
		{
			continue;
		}
		
		string vcodec;
		jsn.getValueString(jFormat, "vcodec", vcodec);
		vcodec = tx.omitDecimal(vcodec, ".", 1);
		
		string acodec;
		jsn.getValueString(jFormat, "acodec", acodec);
		acodec = tx.omitDecimal(acodec, ".", 1);
		
		string va;
		if (vExt != "none" || vcodec != "none")
		{
			if (aExt != "none" || acodec != "none")
			{
				va = "va";	// video with audio
			}
			else
			{
				va = "v";	// video only
			}
		}
		else
		{
			if (aExt != "none" || acodec != "none")
			{
				va = "a";	// audio only
			}
			else
			{
				continue;
			}
		}
		
		string audioCode;
		jsn.getValueString(jFormat, "language", audioCode);
		if (audioCode == "und") audioCode = "";	// undetermined
		
		string audioName;	// audio language name in base_lang on YouTube
		bool audioIsDefault = false;
		int removeDuplicateQuality = cfg.getInt("FORMAT", "remove_duplicate_quality");
		
		if (!multiLang)
		{
			if (!audioCode.empty())
			{
				if (prevAudioCode.empty())
				{
					prevAudioCode = audioCode;
				}
				else if (audioCode != prevAudioCode)
				{
					multiLang = true;
				}
			}
		}
		
		string note;
		jsn.getValueString(jFormat, "format_note", note);
		if (!note.empty())
		{
			if (va == "a" || va == "va")
			{
				if (!audioCode.empty())
				{
					audioIsDefault = (note.find("(default)") >= 0);
				}
				if (isYoutube && multiLang)
				{
					audioName = _SupposeLangName(note);
					_FillAudioName(QualityList, audioCode, audioName);
					
					if (removeDuplicateQuality == 1)
					{
						if (audioCode.empty())
						{
							continue;
						}
						if (va == "a" && _IsDuplicateAudioLang(QualityList, audioCode))
						{
							continue;
						}
					}
					
					if (_HideDubbed(audioCode, va, audioIsDefault))
					{
						continue;
					}
				}
			}
			
			if (va == "v" || va == "va")
			{
				if (!is360)
				{
					if (note.find("equi") >= 0)
					{
						is360 = true;
					}
				}
				if (type3D == 0)
				{
					if (note.find("threed_top_bottom") >= 0)
					{
						//type3D = 3; // T&B Half??
						type3D = 4; // T&B Full??
					}
				}
			}
		}
		
		int height;
		jsn.getValueInt(jFormat, "height", height);
		int width;
		jsn.getValueInt(jFormat, "width", width);
		int longSide = (width < height ? height : width);
		
		float vbr;
		jsn.getValueFloat(jFormat, "vbr", vbr);
		float abr;
		jsn.getValueFloat(jFormat, "abr", abr);
		float tbr;
		jsn.getValueFloat(jFormat, "tbr", tbr);
		
		if (va == "v" || va == "va")
		{
			if (reduceFormats == 1)
			{
				int _count = (va == "v" ? vCount : vaCount);
				if (longSide > 0)
				{
					if (longSide < 600 && _count >= 3) continue;
					if (longSide < 800 && _count >= 6) continue;
					if (longSide < 1200 && _count >= 10) continue;
				}
			}
			else if (reduceFormats == 2)
			{
				int _count = (va == "v" ? vCount : vaCount);
				if (longSide > 0)
				{
					if (longSide > 1300 && _count >= 3) continue;
					if (longSide > 900 && _count >= 6) continue;
					if (longSide > 700 && _count >= 10) continue;
				}
			}
			else if (reduceFormats == 3)
			{
				int _count = (va == "v" ? vCount : vaCount);
				if (longSide > 0)
				{
					if (longSide > 2000) continue;
					if (longSide < 800 && _count >= 4) continue;
				}
			}
		}
		else if (va == "a")
		{
			if (abr > 0)
			{
				if (reduceFormats == 1 || reduceFormats == 3)
				{
					if (abr < 100 && aCount >= 2) continue;
				}
				else if (reduceFormats == 2)
				{
					if (abr > 100 && aCount >= 2) continue;
				}
			}
		}
		
		if (@QualityList !is null)
		{
			string fmtBitrate;
			if (tbr > 0) fmtBitrate = HostFormatBitrate(int(tbr * 1000));
			else if (vbr > 0 && abr > 0) fmtBitrate = HostFormatBitrate(int((abr + vbr) * 1000));
			else if (vbr > 0) fmtBitrate = HostFormatBitrate(int(vbr * 1000));
			else if (abr > 0) fmtBitrate = HostFormatBitrate(int(abr * 1000));
			
			float fmtFps;
			jsn.getValueFloat(jFormat, "fps", fmtFps);
			
			string fmtDynamicRange;
			jsn.getValueString(jFormat, "dynamic_range", fmtDynamicRange);
			if (fmtDynamicRange.empty() && va != "a") fmtDynamicRange = "SDR";
			
			string fmtResolution = "";
			if (width > 0 && height > 0)
			{
				fmtResolution = formatInt(width) + "×" + formatInt(height);
			}
			else
			{
				jsn.getValueString(jFormat, "resolution", fmtResolution);
			}
			
			string fmtId;
			jsn.getValueString(jFormat, "format_id", fmtId);
			
			int itag = 0;
			if (isYoutube)
			{
				if (!fmtId.empty())
				{
					itag = parseInt(fmtId);
//HostPrintUTF8("itag: " + itag);
				}
			}
			
			string fmtQuality;
			string fmtFormat;
			
			if (va == "a")
			{
				float bps = tbr > 0 ? tbr : abr;
				if (bps <= 0) bps = 128;
				fmtQuality = HostFormatBitrate(int(bps * 1000));
				
				fmtFormat += fmtExt;
				if (!acodec.empty() && acodec != "none")
				{
					fmtFormat += ", " + acodec;
				}
				
				if (itag <= 0 || HostExistITag(itag))
				{
					itag = HostGetITag(0, int(bps), fmtExt == "mp4", fmtExt == "webm" || fmtExt == "m3u8");
					if (itag <= 0) itag = HostGetITag(0, int(bps), true, true);
				}
			}
			else if (va == "v")
			{
				if (!fmtResolution.empty()) fmtQuality = fmtResolution;
				
				fmtFormat += fmtExt;
				if (!vcodec.empty() && vcodec != "none")
				{
					fmtFormat += ", " + vcodec;
				}
				
				if (itag <= 0 || HostExistITag(itag))
				{
					itag = HostGetITag(height, 0, fmtExt == "mp4", fmtExt == "webm" || fmtExt == "m3u8");
					if (itag <= 0) itag = HostGetITag(height, 0, true, true);
				}
			}
			else if (va == "va")
			{
				if (!fmtResolution.empty()) fmtQuality = fmtResolution;
				
				fmtFormat += fmtExt;
				if (!vcodec.empty() && vcodec != "none")
				{
					if (!acodec.empty() && acodec != "none")
					{
						fmtFormat += ", " + vcodec + "/" + acodec;
					}
				}
				
				if (itag <= 0 || HostExistITag(itag))
				{
					if (height > 0 && abr < 1) abr = 1;
					itag = HostGetITag(height, int(abr), fmtExt == "mp4", fmtExt == "webm" || fmtExt == "m3u8");
					if (itag <= 0) itag = HostGetITag(height, int(abr), true, true);
				}
			}
			if (fmtQuality.empty())
			{
				jsn.getValueString(jFormat, "format", fmtQuality);
			}
			
			dictionary Quality;
			Quality["url"] = fmtUrl;
			Quality["format"] = fmtFormat;
			Quality["quality"] = fmtQuality;
			if (!fmtResolution.empty()) Quality["resolution"] = fmtResolution;
			if (!fmtBitrate.empty()) Quality["bitrate"] = fmtBitrate;
				//if (!vcodec.empty()) Quality["vcodec"] = vcodec;
				//if (!acodec.empty()) Quality["acodec"] = acodec;
			if (fmtFps > 0) Quality["fps"] = fmtFps;
			
			if (va == "v" || va == "va")
			{
				if (is360) Quality["is360"] = true;
				if (type3D > 0) Quality["type3D"] = type3D;
			}
			
			while (HostExistITag(itag)) itag++;
			HostSetITag(itag);
			Quality["itag"] = itag;
			
			Quality["va"] = va;
			if (!fmtDynamicRange.empty())
			{
				Quality["dynamicRange"] = fmtDynamicRange;
				if (tx.findI(fmtDynamicRange, "SDR") < 0)
				{
					Quality["isHDR"] = true;
				}
			}
			if (!audioCode.empty()) Quality["audioCode"] = audioCode;
			if (!audioName.empty()) Quality["audioName"] = audioName;
			Quality["audioIsDefault"] = audioIsDefault;
			
			if (removeDuplicateQuality == 1)
			{
				if (_IsQualityDuplicate(Quality, QualityList))
				{
					continue;
				}
			}
			
			string fmtReqHeader = _SetRequestHeader(fmtUrl, jFormat);
			Quality["reqHeader"] = fmtReqHeader;
			if (fmtReqHeader.length() > reqHeader.length())
			{
				reqHeader = fmtReqHeader;
			}
			
			if (cfg.csl > 1)
			{
				string msg = "Format: ";
				msg += (va == "v") ? "[video] " : (va == "a") ? "[audio] " : "[video/audio]";
				if (!audioName.empty()) msg += ", " + audioName;
				if (!audioCode.empty()) msg += ", " + audioCode;
				if (!fmtQuality.empty()) msg += ", " + fmtQuality;
				if (!fmtFormat.empty() && fmtFormat != fmtQuality) msg += ", " + fmtFormat;
				if (itag > 0) msg += ", <" + itag + ">";
				msg += "\r\n";
				msg += fmtUrl + "\r\n";
				HostPrintUTF8(msg);
			}
			
			QualityList.insertLast(Quality);
		}
		
		if (va == "va")
		{
			vaCount++;
			
			if (vaOutUrl.empty())
			{
				vaOutUrl = fmtUrl;
			}
			else if (reduceFormats == 1 && longSide > 1100)
			{
				// get if longSide is near 1200
				vaOutUrl = fmtUrl;
			}
			else if (reduceFormats == 2 && longSide < 700)
			{
				// get if longSide is near 640
				vaOutUrl = fmtUrl;
			}
			else if (longSide > 800)
			{
				// get if longSide is near 854
				vaOutUrl = fmtUrl;
			}
		}
		else if (va == "v")
		{
			vCount++;
			if (vOutUrl.empty())
			{
				vOutUrl = fmtUrl;
			}
			else if (reduceFormats == 1 && longSide > 1100)
			{
				// get if longSide is near 1200
				vOutUrl = fmtUrl;
			}
			else if (reduceFormats == 2 && longSide < 700)
			{
				// get if longSide is near 640
				vOutUrl = fmtUrl;
			}
			else if (longSide > 800)
			{
				// get if longSide is near 854
				vOutUrl = fmtUrl;
			}
		}
		else if (va == "a")
		{
			aCount++;
			if (aOutUrl.empty())
			{
				aOutUrl = fmtUrl;
			}
		}
	}
	if (outUrl.empty())
	{
		if (!vOutUrl.empty())
		{
			// prioritize DASH over HLS
			outUrl = vOutUrl;
		}
		else if (!vaOutUrl.empty())
		{
			outUrl = vaOutUrl;
		}
		else if (!aOutUrl.empty())
		{
			outUrl = aOutUrl;
		}
	}
	
	MetaData["playUrl"] = outUrl;
	
	if (string(MetaData["thumbnail"]).empty())
	{
		if (!bool(MetaData["isAudio"]))	// not audio
		{
			MetaData["thumbnail"] = outUrl;
		}
	}
	
	if (is360) MetaData["is360"] = 1;
	if (type3D > 0) MetaData["type3D"] = type3D;
	
	if (@QualityList !is null && QualityList.length() > 0)
	{
		if (isYoutube && multiLang)
		{
			_OrganizeDubbedFormat(QualityList);
		}
		if (is360)
		{
			_FillVR(QualityList, type3D);
		}
	}
	else if (!outUrl.empty())
	{
		if (cfg.csl > 1)
		{
			string msg = "";
			if (!resolution.empty())
			{
				msg += resolution;
			}
			if (!ext.empty())
			{
				if (!resolution.empty()) msg += ", ";
				msg += ext;
			}
			if (!msg.empty())
			{
				msg = "Format: " + msg + "\r\n";
			}
			msg += "URL: " + outUrl + "\r\n";
			HostPrintUTF8(msg);
		}
	}
	
	if (!reqHeader.empty())
	{
		MetaData["reqHeader"] = reqHeader;
		
		if (cfg.csl > 1)
		{
			bool existReferer = (tx.findRegExp(reqHeader, "(?:^|\\n)Referer: ") >= 0);
			bool existCookie = (tx.findRegExp(reqHeader, "(?:^|\\n)Cookie: ") >= 0);
			if (existReferer || existCookie)
			{
				// for Windows PowerShell
				string reqHeader2 = reqHeader;
				reqHeader2.replace("\r", "`r");
				reqHeader2.replace("\n", "`n");
				
				string msg = "Request Header with ";
				if (existReferer)
				{
					msg += "Referer";
				}
				if (existCookie)
				{
					if (existReferer) msg += " & ";
					msg += "Cookie";
				}
				msg += " ---------------------------\r\n";
				msg += reqHeader2;
				msg += "\r\n\r\n";
				HostPrintUTF8(msg);
			}
		}
	}
	
	array<dictionary> subtitleList;
	JsonValue jSubtitles = root["requested_subtitles"];
	if (jSubtitles.isObject())
	{
		array<string> subs = jSubtitles.getKeys();
		for (uint i = 0; i < subs.length(); i++)
		{
			string langCode = subs[i];
			if (tx.findRegExp(langCode, "chat|danmaku|und") >= 0) continue;
			JsonValue jSub = jSubtitles[langCode];
			if (jSub.isObject())
			{
				string subUrl;
				jsn.getValueString(jSub, "url", subUrl);
				if (!subUrl.empty())
				{
					// .vtt.m3u8 -> .vtt
					int pos = tx.findRegExp(subUrl, "(?i)\\.vtt(\\.m3u8)(?:\\?.*)?$");
					if (pos > 0) subUrl.erase(pos, 5);
				}
				string subData;
				jsn.getValueString(jSub, "data", subData);
				
				if (!subUrl.empty() || !subData.empty())
				{
					dictionary subtitle;
					subtitle["langCode"] = langCode;
					if (!subUrl.empty()) subtitle["url"] = subUrl;
					if (!subData.empty()) subtitle["data"] = subData;
					string langName;
					jsn.getValueString(jSub, "name", langName);
					if (!langName.empty()) subtitle["name"] = langName;
					if (tx.findRegExp(langCode, "(?i)\\bAuto") >= 0)
					{
						// Auto-generated
						subtitle["kind"] = "asr";
					}
					subtitleList.insertLast(subtitle);
				}
			}
		}
	}
	uint mainSubCnt = subtitleList.length();
	jSubtitles = root["automatic_captions"];
	if (jSubtitles.isObject())
	{
		array<string> subs = jSubtitles.getKeys();
		for (uint i = 0; i < subs.length(); i++)
		{
			string langCode = subs[i];
			if (_SelectAutoSub(langCode, subtitleList))
			{
				JsonValue jSubs = jSubtitles[langCode];
				if (jSubs.isArray())
				{
					for (int j = jSubs.size() - 1; j >= 0; j--)
					{
						JsonValue jSsub = jSubs[j];
						if (jSsub.isObject())
						{
							string subExt;
							jsn.getValueString(jSsub, "ext", subExt);
							if (!subExt.empty())
							{
								string targetSubExt = "vtt";
								{
									if (ytl.isLangRTL(langCode))
									{
										// PotPlayer has the problem to show RTL subtitles dynamically.
										targetSubExt = "srt";	// or "srv"
									}
								}
								if (tx.findI(subExt, targetSubExt) >= 0)
								{
									string subUrl;
									jsn.getValueString(jSsub, "url", subUrl);
									if (!subUrl.empty())
									{
										dictionary subtitle;
										subtitle["kind"] = "asr";
										subtitle["langCode"] = langCode;
										subtitle["url"] = subUrl;
										string langName;
										jsn.getValueString(jSsub, "name", langName);
										if (!langName.empty())
										{
											langName += " (auto-generated)";
											subtitle["name"] = langName;
										}
										subtitleList.insertLast(subtitle);
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
	if (subtitleList.length() > 0)
	{
		MetaData["subtitle"] = subtitleList;
		
		if (cfg.csl > 1)
		{
			for (uint i = 0; i < subtitleList.length(); i++)
			{
				dictionary subtitle = subtitleList[i];
				string key = (i < mainSubCnt) ? "Sub" : "Auto-Sub";
				string langCode = string(subtitle["langCode"]);
				string langName = string(subtitle["name"]);
				string subUrl = string(subtitle["url"]);
				string subData = string(subtitle["data"]);
				string msg = key + ": [" + langCode + "] " + langName + "\r\n";
				if (!subUrl.empty()) msg += subUrl + "\r\n";
				if (!subData.empty()) msg += "(Raw text data)\r\n";
				HostPrintUTF8(msg);
			}
			HostPrintUTF8("\r\n");
		}
	}
	
	array<dictionary> chapterList;
	JsonValue jChapters = root["chapters"];
	if (jChapters.isArray())
	{
		for(int i = 0; i < jChapters.size(); i++)
		{
			JsonValue jChapter = jChapters[i];
			if (jChapter.isObject())
			{
				string chptTitle;
				jsn.getValueString(jChapter, "title", chptTitle);
				if (!chptTitle.empty())
				{
					float sTime;
					if (jsn.getValueFloat(jChapter, "start_time", sTime))
					{
						int msecTime = int(sTime * 1000);	// milliseconds;
						
						dictionary chapter;
						chapter["title"] = chptTitle;
						if (isLive)
						{
							// For Twitch with --live-from-start
							// Generally PotPlayer cannot reflect chapter positions on live stream.
							if (secDuration > 0)
							{
								int msecDuration = int(secDuration * 1000);
								msecTime -= msecDuration;
								// Negative number means the past
							}
							else
							{
								msecTime = -1;
							}
						}
						chapter["time"] = formatInt(msecTime);
						chapterList.insertLast(chapter);
						if (cfg.csl > 1)
						{
							HostPrintUTF8("Chapter: [" + tx.formatTime(msecTime) + "] " + chptTitle);
						}
					}
				}
			}
		}
	}
	if (isYoutube && !isLive && !cfg.getStr("YOUTUBE", "sponsor_block").empty())
	{
		JsonValue jSBChapters = root["sponsorblock_chapters"];
		if (jSBChapters.isArray() && jSBChapters.size() > 0)
		{
			string untitledChptName = "<Untitled Chapter>";
			int addFirst = 0;
			if (chapterList.length() == 0)
			{
				addFirst = 1;
			}
			else if (parseInt(string(chapterList[0]["time"])) != 0)
			{
				addFirst = 1;
			}
			else if (string(chapterList[0]["title"]) == "<Untitled Chapter 1>")
			{
				chapterList[0]["title"] = untitledChptName;
				addFirst = 2;
			}
			if (addFirst == 1)
			{
				dictionary chapter;
				chapter["title"] = untitledChptName;
				chapter["time"] = "0";
				chapterList.insertAt(0, chapter);
			}
			if (addFirst > 0)
			{
				if (cfg.csl > 1)
				{
					HostPrintUTF8("First Chapter:    [00:00:00.000] " + untitledChptName);
				}
			}
			
			for(uint i = 0; i < sb.CATEGORIES.length(); i++)
			{
				for(int j = 0; j < jSBChapters.size(); j++)
				{
					JsonValue jSBChapter = jSBChapters[j];
					if (jSBChapter.isObject())
					{
						string category;
						jsn.getValueString(jSBChapter, "category", category);
						if (category == sb.CATEGORIES[i])
						{
							string chptTitle;
							jsn.getValueString(jSBChapter, "title", chptTitle);
							float sTime;
							if (jsn.getValueFloat(jSBChapter, "start_time", sTime))
							{
								int msecTime1 = int(sTime * 1000);	// milliseconds
								float eTime;
								jsn.getValueFloat(jSBChapter, "end_time", eTime);
								int msecTime2 = int(eTime * 1000);	// milliseconds
								if (!chptTitle.empty() && msecTime1 >= 0 && msecTime2 > msecTime1)
								{
									string chptTitle1 = sb.reviseChapter(chptTitle);
									string chptTitle2;
									sb.removeChapterRange(chapterList, msecTime1, msecTime2, chptTitle2, cfg.csl > 1);
									if (chptTitle2.empty()) chptTitle2 = untitledChptName;
									
									dictionary chapter1;
									chapter1["title"] = chptTitle1;
									chapter1["time"] = formatInt(msecTime1);
									chapterList.insertLast(chapter1);
									if (cfg.csl > 1)
									{
										HostPrintUTF8("SB Chapter Start: [" + tx.formatTime(msecTime1) + "] " + chptTitle1);
									}
									
									int msecDuration = secDuration * 1000;
									if (msecDuration <= 0 || msecDuration > msecTime2 + sb.THRSH_TIME)
									{
										dictionary chapter2;
										chapter2["title"] = chptTitle2;
										chapter2["time"] = formatInt(msecTime2);
										chapterList.insertLast(chapter2);
										if (cfg.csl > 1)
										{
											HostPrintUTF8("SB Chapter End:   [" + tx.formatTime(msecTime2) + "] " + chptTitle2);
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	if (chapterList.length() > 0)
	{
		MetaData["chapter"] = chapterList;
		if (cfg.csl > 1) HostPrintUTF8("\r\n");
	}
	
	// Keep the hash of yt-dlp.exe, which works without issues.
	if (!ytd.tmpHash.empty() && ytd.tmpHash != cfg.getStr("MAINTENANCE", "ytdlp_hash"))
	{
		cfg.setStr("MAINTENANCE", "ytdlp_hash", ytd.tmpHash);
	}
	ytd.backupExe();
	
	int cancelMode = hist.checkCancel(path, false, startTime);
	if (cancelMode == 2) return "";
	cache.addItem(inUrl, MetaData, QualityList);
	if (cancelMode == 1) return "";
	
	if (cfg.csl > 0)
	{
		HostPrintUTF8("[yt-dlp] Parsing complete (" + extractor + "). - " + tx.qt(inUrl) +"\r\n");
		
		if (tx.findRegExp(reqHeader, "(?:^|\\n)Cookie: ") >= 0)
		{
			string msg = "[yt-dlp] PotPlayer might fail to play this stream due to its lack of cookie support.";
			msg += " - " + tx.qt(inUrl) + "\r\n";
			HostPrintUTF8(msg);
		}
	}
	
	return outUrl;
}


string PlayitemParse(const string &in path, dictionary &MetaData, array<dictionary> &QualityList)
{
	// Called after PlayitemCheck if it returns true
//HostPrintUTF8("PlayitemParse - " + path + "\r\n");
	
	if (cfg.csl > 0) HostOpenConsole();
	
	if (cfg.getInt("TARGET", "playlist_expand_mode") < 0)
	{
		cfg.setInt("TARGET", "playlist_expand_mode", 10, true);
	}
	ytd.playlistForceExpand = 0;
	
	uint startTime = HostGetTickCount();
	hist.add(path, false, startTime);
	
	string outUrl = _PlayitemParse(path, MetaData, QualityList, startTime);
	
	string reqHeader = string(MetaData["reqHeader"]);
	{
		if (!reqHeader.empty())
		{
			HostSetUrlHeaderHTTP(_ReviseUrl(path), reqHeader);
		}
	}
	
	int doubleTrigger = hist.getDoubleTrigger(path, false, startTime);
	if (doubleTrigger > 0 && int(MetaData["playlistSelfCount"]) > 0)
	{
		_PlayerAddList(path, doubleTrigger == 2);
	}
	
	if (false)
	{
		if (bool(hist.list[0]["local"]) && !bool(hist.list[0]["toAlbum"]))
		{
			// Mitigate an issue if the latter local file has been opened.
			HostMessageBox("[yt-dlp] Reopen the current file.\r\nPrevious URL session is conflicting.");
			outUrl = string(hist.list[0]["path"]);
		}
	}
	
	hist.remove(path, false, startTime);
	
	return outUrl;
}

