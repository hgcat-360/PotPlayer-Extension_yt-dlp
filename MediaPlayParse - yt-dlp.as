/*************************************************************
  Parse Streaming with yt-dlp
**************************************************************
  Extension script for PotPlayer 260114 or later versions
  Placed in \PotPlayer\Extension\Media\PlayParse\
*************************************************************/

string SCRIPT_VERSION = "260202";


string YTDLP_EXE = "yt-dlp.exe";
	// yt-dlp executable file. Placed in "ytdlp_location". (required)

string SCRIPT_CONFIG_DEFAULT = "yt-dlp_default.ini";
	// Default configuration file. Placed in HostGetScriptFolder(). (required)

string SCRIPT_CONFIG_CUSTOM = "Extension\\Media\\PlayParse\\yt-dlp.ini";
	// Configuration file. Relative path to HostGetConfigFolder().
	// Created automatically with this script.

string RADIO_IMAGE_1 = "yt-dlp_radio1.jpg";
string RADIO_IMAGE_2 = "yt-dlp_radio2.jpg";
	// Radio image files. Placed in HostGetScriptFolder().


string USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36";	// chrome
//string USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:144.0) Gecko/20100101 Firefox/144.0";	// firefox




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
				if (!HostRegExpParse(str, "^\\w+=", {}))
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
		pos = sch.findRegExp(str, "^\\[([^\n\r\t\\]]*?)\\]", section, pos);
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
		pos = sch.findRegExp(str, "^(#?\\w+)=", key, pos);
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
		int pos = sch.findRegExp(sectArea, "^[^\t\r\n]*\\b" + key + " *=");
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
			pos2 = sch.findRegExp(keyArea, "^\t[^\r\n]*\r\n", line, pos1);
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
		
		kd.value = HostRegExpParse(kd.areaStr, "^" + kd.key + "=(\\S[^\t\r\n]*)");
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
			"(?i)^[^\t\r\n]*\\b" + kd.key + " *=",	// comment out
			"(?i)^ *" + kd.key + " *= *",	// empty value
			"(?i)^ *" + kd.key + " *= *(\\S[^\t\r\n]*)"	// specified value
		};
		
		if (kd.key.empty()) {kd.init(); return;}
		string str = kd.areaStr;
		if (str.empty()) {kd.init(); return;}
		
		string value;
		int keyTop = -1;
		int valueTop = -1;
		int state;
		for (state = 2; state >= 0; state--)
		{
			array<dictionary> match;
			keyTop = sch.regExpParse(str, patterns[state], match, 0);
			if (keyTop >= 0)
			{
				string s1;
				match[0].get("str", s1);
				if (state > 0)
				{
					str.erase(keyTop, s1.length());
					str.insert(keyTop, kd.key + "=");
					valueTop = keyTop + kd.key.length() + 1;
				}
				if (state == 2)
				{
					value = string(match[1]["str"]);
					int pos2 = int(match[1]["pos"]);
					value.Trim();
					if (!value.empty())
					{
						str.insert(valueTop, value);
						break;
					}
				}
				else if (state == 1)
				{
					value = _getValue(kd.section, kd.key, 1);
					if (!value.empty()) str.insert(valueTop, value);
					break;
				}
				else if (state == 0)
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
		kd.state = state >= 0 ? 1 : 0;
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
						int idx = sch.findI(sections, section);
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
		if (sections.length() == 0 || kds.getSize() == 0) return "";
		
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
		if (sections.length() == 0 || kds.getSize() == 0) return "";
		
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
		if (sections.length() == 0 || kds.getSize() == 0) return "";
		
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
				autoSubLangs = sch.trimSplit(asLang, ",");
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
		return sch.escapeQuote(_getValue(section, key, useDef));
	}
	
	string getStr(string key, int useDef = 0)
	{
		return sch.escapeQuote(_getValue("", key, useDef));
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
		return sch.escapeQuote(prevValue);
	}
	
	string setStr(string key, string sValue, bool save = true)
	{
		string prevValue = _setValue("", key, sValue, save);
		return sch.escapeQuote(prevValue);
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


class SCH
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
	
	string escapeQuote(string str)
	{
		// Do not use Trim("\"")
		if (str.Left(1) == "\"" && str.Right(1) == "\"")
		{
			int pos = str.find("\"", 1);
			if (pos == int(str.length() - 1))
			{
				str = str.substr(1, str.length() - 2);
				return str;
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
	
	string formatTime(int msTime)
	{
		string minus = "";
		if (msTime < 0)
		{
			msTime *= -1;
			minus = "-";
		}
		int second = msTime / 1000;
		int ms = msTime % 1000;
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

SCH sch;

//----------------------- END of class SCH -------------------------



class SHOUTPL
{
	
	string _removeNumber(string title)
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
			string title = _GetDataField(data, "Title" + (i + 1), "=");
			if (!title.empty())
			{
				title = _removeNumber(title);
				if (i == 0) getTitle = title;
				else if (title != getTitle) break;
			}
			string fmtUrl = _GetDataField(data, "File" + (i + 1), "=");
			if (fmtUrl.empty()) break;
			if (outUrl.empty()) outUrl = fmtUrl;
			
			if (@QualityList !is null)
			{
				dictionary dic;
				dic["url"] = fmtUrl;
				dic["format"] = _getFormat(fmtUrl, i);
				dic["itag"] = _setItag();
				QualityList.insertLast(dic);
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
			pos = sch.regExpParse(data, "^#EXTINF:(?:[^,\r\n]*),([^,\r\n]*)\\r?\\n([^\r\n]+)\\r?\\n", match, pos);
			if (pos < 0) break;
			
			string s0 = string(match[0]["str"]);
			pos += s0.length();
			string title = string(match[1]["str"]);
			{
				title = _removeNumber(title);
				if (i == 0) getTitle = title;
				else if (title != getTitle) break;
			}
			string fmtUrl = string(match[2]["str"]);
			if (outUrl.empty()) outUrl = fmtUrl;
			
			if (@QualityList !is null)
			{
				dictionary dic;
				dic["url"] = fmtUrl;
				dic["format"] = _getFormat(fmtUrl, i);
				dic["itag"] = _setItag();
				QualityList.insertLast(dic);
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
			pos = sch.regExpParse(data, "<track>(.+?)</track>", match, pos);
			if (pos < 0) break;
			
			string s0 = string(match[0]["str"]);
			pos += s0.length();
			string track = string(match[1]["str"]);
			string title = HostRegExpParse(track, "<title>(.+?)</title>");
			{
				title = _removeNumber(title);
				if (i == 0) getTitle = title;
				else if (title != getTitle) break;
			}
			string fmtUrl = HostRegExpParse(track, "<location>(.+?)</location>");
			if (outUrl.empty()) outUrl = fmtUrl;
			
			if (@QualityList !is null)
			{
				dictionary dic;
				dic["url"] = fmtUrl;
				dic["format"] = _getFormat(fmtUrl, i);
				dic["itag"] = _setItag();
				QualityList.insertLast(dic);
			}
		}
		return outUrl;
	}
	
	string parse(string url, dictionary &MetaData, array<dictionary> &QualityList, bool addLocation)
	{
		string ext = HostRegExpParse(url, "/tunein-station\\.(pls|m3u|xspf)\\?");
		if (!ext.empty())
		{
			string data = _GetHttpContent(url, 5, 4095);
			if (!data.empty())
			{
				string outUrl;
				string title;
				if (ext == "pls") outUrl = _parsePls(data, title, QualityList);
				if (ext == "m3u") outUrl = _parseM3u(data, title, QualityList);
				if (ext == "xspf") outUrl = _parseXspf(data, title, QualityList);
				
				if (!outUrl.empty())
				{
					MetaData["url"] = url;
					MetaData["webUrl"] = url;
					title = _ReviseWebString(title);
					title = _CutOffString(title);
					MetaData["title"] = title;
						// station name that will be replaced to a current music title after playback starts
					MetaData["author"] = title + (addLocation ? " @ShoutcastPL" : "");
					MetaData["vid"] = HostRegExpParse(url, "\\?id=(\\d+)");
					MetaData["fileExt"] = ext;
					if (cfg.getInt("FORMAT", "radio_thumbnail") == 1)
					{
						MetaData["thumbnail"] = _GetRadioThumb("shoutcast");
					}
					return outUrl;
				}
			}
		}
		return "";
	}
	
	void passPlaylist(string url, array<dictionary> &dicsEntry)
	{
		dictionary dic;
		dic["url"] = url;
		dic["thumbnail"] = _GetRadioThumb("shoutcast");
		dicsEntry.insertLast(dic);
	}
	
	uint extractPlaylist(string url, array<dictionary> &dicsEntry)
	{
		dictionary meta;
		array<dictionary> dicsMeta;
		if (!parse(url, meta, dicsMeta, false).empty())
		{
			string etrTitle = string(meta["title"]);
			string etrAuthor = string(meta["author"]);
			string etrThumb = string(meta["thumbnail"]);
			for (uint i = 0; i < dicsMeta.length(); i++)
			{
				dictionary dic;
				string etrUrl = string(dicsMeta[i]["url"]);
				dic["url"] = etrUrl;
				dic["title"] = etrTitle;
				dic["author"] = etrAuthor;
				dic["thumbnail"] = etrThumb;
				dicsEntry.insertLast(dic);
			}
			return dicsMeta.length();
		}
		return 0;
	}
	
}

SHOUTPL shoutpl;

//----------------------- END of class SHOUTPL -------------------------



class YTDLP
{
	string exePath;
	string version;
	string tmpHash;
	array<string> errors = {"(OK)", "(NOT FOUND)", "(LOOKS INVALID)", "(CRITICAL ERROR!)"};
	int error = 0;
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
		
		FileVersion verInfo;
		if (!verInfo.Open(exePath))
		{
			error = 2; return;
		}
		else
		{
			bool doubt = false;
			if (verInfo.GetProductName() != "yt-dlp" || verInfo.GetInternalName() != "yt-dlp")
			{
				doubt = true;
			}
			else if (verInfo.GetOriginalFilename() != "yt-dlp.exe")
			{
				doubt = true;
			}
			else if (verInfo.GetCompanyName() != "https://github.com/yt-dlp")
			{
				doubt = true;
			}
			/*
			// The copyright property in verInfo was removed from yt-dlp 250907
			else if (verInfo.GetLegalCopyright().find("UNLICENSE") < 0)
			{
				doubt = true;
			}
			*/
			else if (verInfo.GetProductVersion().find("Python") < 0)
			{
				doubt = true;
			}
			else
			{
				version = verInfo.GetFileVersion();	// get version
				if (version.empty())
				{
					doubt = true;
				}
			}
			
			verInfo.Close();
			if (doubt)
			{
				error = 2; return;
			}
		}
		if (error > 0) error = 0;
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
			if (tmpHash.empty())
			{
				string bkHash = cfg.getStr("MAINTENANCE", "ytdlp_hash");
				if (bkHash.empty() || bkHash != exeHash)
				{
					isNew = true;
				}
			}
			else
			{
				if (exeHash != tmpHash)
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
		string msg = "Your \"yt-dlp.exe\" did not work as expected.\r\n";
		//HostPrintUTF8("\r\n[yt-dlp] CRITICAL ERROR! " + msg);
		msg += "If there are no problems, set [critical_error] to 0 in the config file and reload the script.";
		HostMessageBox(msg, "[yt-dlp] CRITICAL ERROR", 3, 2);
	}
	
	bool _fileCopy(string srcPath, string dstPath)
	{
		// Hidden files are not supported.
		string cmd = "cmd.exe";
		string para = "/c copy /y /b /v";
		para += " " + qt("\\\\?\\" + srcPath);
		para += " " + qt("\\\\?\\" + dstPath);
		string ret = HostExecuteProgram(cmd, para);
//HostPrintUTF8("ret: " + ret);
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
		string output = HostExecuteProgram(qt(exePath), " -U");
		
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
			int pos1 = sch.findRegExp(log, "^\\[debug\\] Downloading yt-dlp\\.exe ");
			if (pos1 >= 0)
			{
				int pos2 = sch.findRegExp(log, "(?i)^ERROR: Unable to write to[^\r\n]+yt-dlp\\.exe", pos1);
				if (pos2 >= 0)
				{
					cfg.setInt("MAINTENANCE", "update_ytdlp", 0);
					
					if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Auto update failed.\r\n");
					string msg =
						"A newer version of \"yt-dlp.exe\" was found on the website, but the automatic update failed.\r\n"
						"\r\n"
						"Unable to overwrite:\r\n";
					msg += exePath + "\r\n"
						"\r\n"
						"Please replace it manually, or try running PotPlayer as an administrator.\r\n"
						"You can also change the [ytdlp_location] setting to a location with write permission.\r\n"
						"\r\n"
						"The [update_ytdlp] setting has been reset.";
					HostMessageBox(msg, "[yt-dlp] ALERT: Auto Update", 0, 0);
					return -1;
				}
				
				if (checkFileInfo() > 0)
				{
					cfg.setInt("MAINTENANCE", "update_ytdlp", 0);
					
					if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Auto update failed.\r\n");
					string msg =
						"Automatic update seems to have failed."
						"\r\n\r\n"
						"The [update_ytdlp] setting has been reset.";
					
					restoreExe();
					if (checkFileInfo() > 0)
					{
						msg += "\r\nPlease replace \"yt-dlp.exe\" with a working version manually.";
						HostMessageBox(msg, "[yt-dlp] ERROR: Auto Update", 0, 0);
						return -2;
					}
					else
					{
						HostMessageBox(msg, "[yt-dlp] ERROR: Auto Update", 0, 0);
						return -1;
					}
				}
				
				int pos3 = sch.findRegExp(log, "^Updated yt-dlp to", pos1);
				if (pos3 >= 0)
				{
					tmpHash = _fileHash(exePath);
					
					if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Auto update successful.\r\n");
					string msg = sch.getLine(log, pos3);
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
		int pos = sch.findI(log, words);
		if (pos >= 0)
		{
			pos += words.length();
			string msg = sch.getLine(log, pos);
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] ERROR! " + msg + "\r\n");
			HostMessageBox(msg, "[yt-dlp] ERROR: Cpmmand", 0, 0);
			return true;
		}
		if (sch.findI(log, "[debug] Command-line config:") < 0)
		{
			string msg = "No command line info.";
			HostPrintUTF8("[yt-dlp] CRITICAL ERROR! " + msg + "\r\n");
			HostMessageBox(msg, "[yt-dlp] CRITICAL ERROR: Cpmmand", 3, 1);
			criticalError();
			return true;
		}
		return false;
	}
	
	bool _checkLogVersion(string log)
	{
		int pos = log.find("\n[debug] yt-dlp version");
		if (pos >= 0)
		{
			pos += 1;
			string line = sch.getLine(log, pos);
			if (line.find(version) >= 0)
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
		if (sch.findRegExp(log, "(?i)^ERROR: Could not [^\r\n]+? cookies? database") >= 0) check = true;
		if (sch.findRegExp(log, "(?i)^ERROR: Failed to decrypt with DPAPI") >= 0) check = true;
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
		int pos1 = sch.findRegExp(log, "(?i)\nERROR: \\[youtube\\] [^\r\n]*(Unsupported language code:)");
		if (pos1 >= 0)
		{
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] ERROR! Your language code [base_lang] is not supported for the menu label on YouTube.\r\n");
			int pos2 = sch.findEol(log, pos1);
			string msg = log.substr(pos1, pos2 - pos1);
			int pos = sch.findRegExp(msg, ". Supported language codes");
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
	
	bool _checkLogGeoRestriction(string log, string url)
	{
		if (sch.findRegExp(log, "(?i)Error: [^\r\n]* not available [^\r\n]+ geo restriction") >= 0)
		{
			string msg = "This content is not available from your location due to geo restriction.";
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] " + msg + " - " + qt(url) + "\r\n");
			HostMessageBox(msg + "\r\n" + url, "[yt-dlp] INFO: Geo Restriction", 2, 1);
			return true;
		}
		return false;
	}
	
	bool _checkLogLiveOffline(string log, string url)
	{
		if (sch.findRegExp(log, "(?i)^ERROR: [^\r\n]* (not currently live|off ?line)") >= 0)
		{
			string msg = "This channel is not live now.";
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] " + msg + " - " + qt(url) + "\r\n");
			HostMessageBox(msg + "\r\n" + url, "[yt-dlp] INFO: No Live", 2, 1);
			return true;
		}
		return false;
	}
	
	bool _checkLogServerBlock(string log, string url)
	{
		int pos = sch.findRegExp(log, "(?i)^ERROR: [^\r\n]* wait and try later");
		if (pos >= 0)
		{
			string msg = sch.getLine(log, pos);
			msg = msg.substr(7);
			if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] " + msg + " - " + qt(url) + "\r\n");
			HostMessageBox(msg + "\r\n" + url, "[yt-dlp] INFO: Server", 2, 1);
			return true;
		}
		return false;
	}
	
	bool _checkLogLiveFromStart(string log)
	{
		if (sch.findRegExp(log, "(?i)^ERROR: ?\\[twitch:stream\\][^\r\n]*--live-from-start") >= 0)
		{
			return true;
		}
		return false;
	}
	
	bool _checkLogForbidden(string log)
	{
		if (sch.findRegExp(log, "(?i)^ERROR: [^\r\n]*HTTP Error 40\\d:") >= 0)
		{
			return true;
		}
		return false;
	}
	
	bool checkLogJsRuntime(string log)
	{
		if (sch.findRegExp(log, "(?i)WARNING: \\[youtube\\] [^\r\n]*challenge solving failed") >= 0)
		{
			if (sch.findRegExp(log, "(?i)JS runtimes: none") >= 0)
			{
				return true;
			}
		}
		return false;
	}
	
	void _printNoEntries(string log, string url)
	{
		if (cfg.csl > 0)
		{
			string msg;
			if (log.find("ERROR") >= 0)
			{
				if (checkLogJsRuntime(log))
				{
					msg = "Parsing failed. Use a JS runtime such as \"Deno.exe\".";
				}
				else
				{
					msg = "Unsupported.";
				}
				HostPrintUTF8("[yt-dlp] " + msg + " - " + qt(url) + "\r\n");
			}
			else if (sch.findI(log, "downloading 0 items") >= 0)
			{
				msg = "No entries in this playlist.";
				HostPrintUTF8("[yt-dlp] " + msg + " - " + qt(url) + "\r\n");
			}
			else
			{
				msg = "No data or info.";
				HostPrintUTF8("[yt-dlp] ERROR! " + msg + " - " + qt(url) + "\r\n");
			}
		}
	}
	
	string _extractLines(string log)
	{
		string outStr = "";
		_removeMetadata(log);
		int pos1 = 0;
		int pos0;
		string log0;
		do {
			pos0 = pos1;
			pos1 = sch.findRegExp(log, "(?i)(error|warning)", pos1);
			if (pos1 >= 0)
			{
				string line = sch.getLine(log, pos1);
				if (sch.findI(line, "[debug]") != 0)
				{
					if (sch.findI(line, "  File \"") != 0)
					{
						outStr += line + "\r\n";
					}
				}
				pos1 = sch.findNextLineTop(log, pos1);
			}
		} while (pos1 > pos0);
		
		return outStr;
	}
	
	bool _removeMetadata(string &inout log)
	{
		// Remove the metadata area that cannot be used for judgment.
		string reg = "(?i)(\\n\\[debug\\] ffmpeg command line:.+?)\\n(?:\\[|error:|warning:)";
		string _s;
		int pos = sch.findRegExp(log, reg, _s);
		if (pos >= 0)
		{
			log.erase(pos, _s.length());
			return true;
		}
		return false;
	}
	
	array<string> _getEntries(string str, uint &out logPos)
	{
		array<string> entries;
		logPos = 0;
		
		int pos = -1;
		if (str.Left(1) == "{") pos = 0;
		else pos = str.find("\n{", 0);
		
		int top0;
		do {
			top0 = pos;
			if (pos > 0) pos += 1;
			int pos2 = str.find("}\n", pos);
			if (pos2 < 0) break;
			pos2 += 1;
			string entry = str.substr(pos, pos2 - pos);
			entries.insertLast(entry);
			logPos = pos2 + 1;
			pos = str.find("\n{", pos2);
		} while (pos > top0);
		
		return entries;
	}
	
	array<string> _getEntries(string str)
	{
		uint logPos;
		return _getEntries(str, logPos);
	}
	
	array<string> _getErrIds(string log)
	{
		array<string> errIds = {};
		int pos1 = 0;
		int pos0;
		do {
			pos0 = pos1;
			string id;
			pos1 = sch.findRegExp(log, "^ERROR: \\[\\w+\\] ([-\\w@]+): ", id, pos1);
			if (!id.empty())
			{
				errIds.insertLast(id);
			}
		} while (pos1 > pos0);
		return errIds;
	}
	
	array<string> exec1(string url, int playlistMode, string referer)
	{
		if (checkFileInfo() > 0) return {};
		checkFileHash();
		
		bool isYoutube = _IsUrlSite(url, "youtube");
		
		bool checkBiliPart = false;
		if (_IsPotentialBiliPart(url))
		{
			if (playlistMode == 1)
			{
				playlistMode = 2;
			}
			else if (playlistMode == 0)
			{
				checkBiliPart = true;
			}
		}
		
		string options = "";
		
		if (playlistMode <= 0)
		{
			// a single video/audio
			
			if (cfg.csl > 0)
			{
				string msg = "\r\n[yt-dlp] ";
				if (playlistMode < 0) msg += "Retry ";
				msg += "Parsing";
				if (!referer.empty()) msg += " wtih referer";
				msg += "... - " + qt(url) + "\r\n";
				HostPrintUTF8(msg);
			}
			
			if (checkBiliPart)
			{
				options += " -I -1";	// to get playlist_count
				options += " --yes-playlist";
			}
			else
			{
				options += " -I 1";
				options += " --no-playlist";
			}
			
			options += " --all-subs";
			
			if (playlistMode != -1)
			{
				if (_IsUrlSite(url, "twitch.tv"))	// for twitch
				{
					if (cfg.getInt("FORMAT", "live_as_vod") == 1)
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
			
			if (isYoutube)
			{
				string sb = cfg.getStr("YOUTUBE", "sponsor_block");
				if (!sb.empty())
				{
					options += " --sponsorblock-mark " + qt(sb);
				}
			}
		}
		else
		{
			// playlist
			
			if (cfg.csl > 0)
			{
				HostPrintUTF8("\r\n[yt-dlp] Extracting playlist entries... - " + qt(url) + "\r\n");
			}
			
			if (playlistMode == 1)
			{
				options += " --no-playlist";
			}
			else	// playlistMode == 2
			{
				options += " --yes-playlist";
			}
			
			options += " --flat-playlist";
				// Fastest and reliable for collecting urls in a playlist.
				// But collected items have no title or thumbnail except for some websites like youtube.
				// Missing properties (title/thumbnail/duration) are fetched by a subsequent function "_getMetadata".
			
		}
		
		bool hasCookie = _addOptionsCookie(options);
		
		if (isYoutube)
		{
			string youtubeArgs = _getYoutubeArgs(hasCookie);
			options += " --extractor-args " + qt(youtubeArgs);
		}
		
		//options += " -R 3";	// default; 10
		options += " --encoding \"utf8\"";	// prevent garbled text
		
		_addOptionsNetwork(options);
		if (!referer.empty())
		{
			options += " --add-headers " + qt("Referer: " + referer);
		}
		
		string proxy = cfg.getStr("NETWORK", "proxy");
		
		if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 1)
		{
			if (!tmpHash.empty() && tmpHash == cfg.getStr("MAINTENANCE", "ytdlp_hash"))
			{
				options += " -U";
			}
		}
		
		options += " -j";	// "-j" must be in lower case
		
		// Execute
		string output;
		if (playlistMode <= 0)
		{
			options += " -v";
			options += " -- " + url;
			HostIncTimeOut(30000);
			output = HostExecuteProgram(qt(exePath), options);
		}
		else
		{
			output = _extractPlaylist(url, options);
		}
		
		uint logPos = 0;
		array<string> entries = _getEntries(output, logPos);
		string log = output.substr(logPos).TrimLeft("\r\n");
		
		if (cfg.csl == 1)
		{
			HostPrintUTF8(_extractLines(log));
		}
		else if (cfg.csl == 2)
		{
			HostPrintUTF8(log);
		}
		else if (cfg.csl == 3)
		{
			HostPrintUTF8(output);
		}
		
		if (_checkLogCommand(log)) return {};
		
		int update = _checkLogUpdate(log);
		if (update > 0)
		{
			// Restart with the new yt-dlp automatically
		}
		else if (update == -2)
		{
			return {};
		}
		else	// update: 0 or -1
		{
			if (_checkLogVersion(log)) return {};
		}
		
		if (_checkLogBrowser(log)) return {};
		if (_checkLogLanguageCode(log)) return {};
		if (_checkLogGeoRestriction(log, url)) return {};
		if (_checkLogServerBlock(log, url)) return {};
		if (_checkLogLiveOffline(log, url)) return {};
		
		if (_checkLogLiveFromStart(log))
		{
			if (playlistMode != -1)
			{
				if (options.find(" --live-from-start") >= 0)
				{
					// Retry without --live-from-start
					return exec1(url, -1, referer);
				}
			}
		}
		
		if (_checkLogForbidden(log))
		{
			if (referer.empty())
			{
				referer = cfg.getStr("NETWORK", "referer");
				if (!referer.empty())
				{
					// Retry with the referer
					return exec1(url, playlistMode, referer);
				}
			}
		}
		
		if (entries.length() == 0)
		{
			_printNoEntries(log, url);
		}
		
		return entries;
	}
	
	
	array<string> exec2(array<string> urls, int singleMode, array<string> &out errIds)
	{
		if (urls.length() == 0) return {};
		
		if (cfg.csl > 0)
		{
			string msg;
			msg += "\r\n[yt-dlp] ";
			if (singleMode == 0)
			{
				msg += "Extracting nested playlist entries... - ";
			}
			else if (singleMode == -1)
			{
				msg += "Collecting thumbnails... - ";
			}
			else
			{
				msg += "Collecting metadata... - ";
			}
			msg += qt(urls[0]);
			if (urls.length() == 2)
			{
				msg += " and " + qt(urls[1]) + ".\r\n";
			}
			else if (urls.length() > 2)
			{
				msg += " and " + (urls.length() - 1) + " URLs.\r\n";
			}
			HostPrintUTF8(msg);
		}
		
		string options = "";
		
		if (singleMode >= 0)
		{
			options += " --flat-playlist";
		}
		
		if (singleMode == 3)	// for the potential bilibili part
		{
			options += " -I -1";	// to get playlist_count
			options += " --yes-playlist";
		}
		else
		{
			if (singleMode != 0) options += " -I 1";
			options += " --no-playlist";
		}
		
		//options += " -R 3";	// default; 10
		options += " --encoding \"utf8\"";	// prevent garbled text
		
		_addOptionsNetwork(options);
		
		bool hasCookie = _addOptionsCookie(options);
		
		if (_IsUrlSite(urls[0], "youtube"))
		{
			string youtubeArgs = _getYoutubeArgs(hasCookie);
			options += " --extractor-args " + qt(youtubeArgs);
			
			//options += " --no-js-runtimes";	// Don't use Deno
		}
		
		options += " -j";	// "-j" must be in lower case
		
		// Execute
		string output;
		if (singleMode == 0)
		{
			output = _extractPlaylist2(urls, options);
		}
		else
		{
			output = _getMetadata(urls, options, singleMode);
		}
		
		uint logPos = 0;
		array<string> entries = _getEntries(output, logPos);
		string log = output.substr(logPos).TrimLeft("\r\n");
		
		errIds = _getErrIds(log);
		
		if (cfg.csl == 3)
		{
			HostPrintUTF8(output);
		}
		else if (singleMode == 0 || singleMode == 2 || singleMode == 3)
		{
			if (cfg.csl == 1)
			{
				//HostPrintUTF8(_extractLines(log));
			}
			else if (cfg.csl == 2)
			{
				HostPrintUTF8(log);
			}
		}
		
		return entries;
	}
	
	array<string> exec2(array<string> urls, int singleMode)
	{
		array<string> errIds;
		return exec2(urls, singleMode, errIds);
	}
	
	uint countItemsAll(string joinedUrl)
	{
		// Count all items in playlist urls
		
		string options;
		options += " -I -1";	// specify the last item to count up
		options += " -j";
		options += " --flat-playlist";
		options += " -R 3";
		bool hasCookie = _addOptionsCookie(options);
		string youtubeArgs = _getYoutubeArgs(hasCookie);
		options += " --extractor-args " + qt(youtubeArgs);
		
		_addOptionsNetwork(options);
		options += " -- " + joinedUrl;
		
		HostIncTimeOut(60000);
		string output = HostExecuteProgram(qt(exePath), options);
		
		array<string> entries = _getEntries(output);
		
		string msg = "";
		int totalCnt = 0;
		
		for (uint i = 0; i < entries.length(); i++)
		{
			int cnt = _GetDataValueInt(entries[i], "playlist_count");
			if (cnt > 0) totalCnt += cnt;
			msg += (i == 0) ? "  " : " + ";
			msg += cnt;
		}
		
		if (cfg.csl > 0) HostPrintUTF8(msg + "\r\n");
		return totalCnt;
	}
	
	bool _addOptionsCookie(string &inout options)
	{
		bool hasCookie = false;
		string cookieFile = cfg.getStr("COOKIE", "cookie_file");
		if (!cookieFile.empty())
		{
			options += " --cookies " + qt(cookieFile);
			hasCookie = true;
		}
		else
		{
			string cookieBrowser = cfg.getStr("COOKIE", "cookie_browser");
			if (!cookieBrowser.empty())
			{
				options += " --cookies-from-browser " + qt(cookieBrowser);
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
			if (!bgutilHttp.empty())
			{
				options += " --extractor-args " + qt("youtubepot-bgutilhttp:" + bgutilHttp);
			}
			string bgutilScript = cfg.getStr("YOUTUBE", "potoken_bgutil_script");
			if (!bgutilScript.empty())
			{
				options += " --extractor-args " + qt("youtubepot-bgutilscript:" + bgutilScript);
			}
		}
		
		return hasCookie;
	}
	
	string _getYoutubeArgs(bool hasCookie)
	{
		string youtubeArgs = "youtube:";
		youtubeArgs += "lang=" + cfg.baseLang;
		youtubeArgs += ";player-client=default,mweb";
		string bgutil;
		string potokenGvs;
		if (hasCookie)
		{
			bgutil = cfg.getStr("YOUTUBE", "potoken_bgutil");
			if (bgutil.empty())
			{
				potokenGvs = cfg.getStr("YOUTUBE", "potoken_gvs");
			}
		}
		
		string potokenSubs = cfg.getStr("YOUTUBE", "potoken_subs");
		if (!potokenGvs.empty())
		{
			youtubeArgs += ";potoken=mweb.gvs+" + potokenGvs;
			if (!potokenSubs.empty())
			{
				youtubeArgs += ",web.subs+" + potokenSubs;
			}
		}
		else
		{
			if (!potokenSubs.empty())
			{
				youtubeArgs += ";po_token=web.subs+" + potokenSubs;
			}
			if (!bgutil.empty())
			{
				youtubeArgs += ";" + bgutil;
			}
		}
		
		return youtubeArgs;
	}
	
	void _addOptionsNetwork(string &inout options)
	{
		options += " --retry-sleep exp=1:10";
		
		string proxy = cfg.getStr("NETWORK", "proxy");
		if (!proxy.empty()) options += " --proxy " + qt(proxy);
		
		int socketTimeout = cfg.getInt("FORMAT", "socket_timeout");
		if (socketTimeout > 0) options += " --socket-timeout " + socketTimeout;
		
		string sourceAddress = cfg.getStr("NETWORK", "source_address");
		if (!sourceAddress.empty()) options += " --source-address " + qt(sourceAddress);
		
		string geoProxy = cfg.getStr("NETWORK", "geo_verification_proxy");
		if (!geoProxy.empty()) options += " --geo-verification-proxy " + qt(geoProxy);
		
		string xff = cfg.getStr("NETWORK", "xff");
		if (!xff.empty()) options += " --xff " + qt(xff);
		
		int ipv = cfg.getInt("NETWORK", "ip_version");
		if (ipv == 4) options += " -4";
		else if (ipv == 6) options += " -6";
		
		if (cfg.getInt("NETWORK", "no_check_certificates") == 1)
		{
			options += " --no-check-certificates";
		}
	}
	
	void _eraseYoutubeTabError(string &inout output)
	{
		int pos = 0;
		while (pos >= 0)
		{
			pos = sch.findRegExp(output, "^ERROR: \\[youtube:tab\\] [^\r\n]+ does not have a [^\r\n]+ tab", pos);
			if (pos >= 0) sch.eraseLine(output, pos);
		}
	}
	
	uint _countJson(string &inout data, bool eraseMessage)
	{
		uint cnt = 0;
		int pos = 0;
		do {
			string c = data.substr(pos, 1);
			if (c == "{")
			{
				cnt++;
				pos = sch.findNextLineTop(data, pos);
			}
			else if (eraseMessage)
			{
				sch.eraseLine(data, pos);
			}
			else
			{
				pos = sch.findNextLineTop(data, pos);
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
				int pos2 = sch.findLineTop(data, pos1);
				if (data.substr(pos2, 1) == "{")
				{
					return pos1 + 3;
				}
				pos1 = sch.findLineTop(data, pos1);
			}
		} while (pos1 > pos0);
		return 0;
	}
	
	string _extractPlaylist(string url, string options)
	{
		if (url.empty()) return "";
		string output;
		int waitTime = cfg.getInt("TARGET", "playlist_items_timeout");
		if (waitTime < 0)
		{
			cfg.setInt("TARGET", "playlist_items_timeout", 0);
			waitTime = 0;
		}
		
		if (waitTime == 0)
		{
			HostIncTimeOut(2000000);
			uint startTime = HostGetTickCount();
			output = HostExecuteProgram(qt(exePath), " -v" + options + " -- " + url);
			
			if (cfg.csl > 0)
			{
				uint cnt = _countJson(output, false);
				int elapsedTime = (HostGetTickCount() - startTime)/1000;
				if (elapsedTime < 0) elapsedTime = -1;
				string msg;
				msg = "  count: " + cnt;
				msg += "\t\ttime: " + elapsedTime + " sec";
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
			string joinedUrl = _ChangeUrlYoutubeChannelTop(url);
			if (joinedUrl != url)
			{
				youtubeChannelTop = true;
				url = joinedUrl;
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
				string addOutput = HostExecuteProgram(qt(exePath), wholeOption);
				uint addCnt = _countJson(addOutput, (i > 1));
				if (youtubeChannelTop) _eraseYoutubeTabError(addOutput);
				output.insert(_findJsonEnd(output), addOutput);
				cnt += addCnt;
				if (addCnt > 0)
				{
					int elapsedTime = (HostGetTickCount() - startTime)/1000;
					if (elapsedTime < 0) elapsedTime = -1;
					if (cfg.csl > 0)
					{
						string msg = "  count: " + cnt;
						msg += "\t\ttime: " + elapsedTime + " sec";
						HostPrintUTF8(msg);
					}
					if (addCnt < unitIdx/2)
					{
						complete = 1;
						break;
					}
					if (elapsedTime < 0 || elapsedTime > waitTime)
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
		return output;
	}
	
	string _extractPlaylist2(array<string> urls, string options)
	{
		if (urls.length() == 0) return "";
		string output;
		string joinedUrl = "";
		for (uint i = 0; i < urls.length(); i++) joinedUrl += " " + urls[i];
		
		int waitTime = cfg.getInt("TARGET", "playlist_items_timeout");
		if (waitTime == 0)
		{
			HostIncTimeOut(2000000);
			uint startTime = HostGetTickCount();
			output = HostExecuteProgram(qt(exePath), options + " --" + joinedUrl);
			
			if (cfg.csl > 0)
			{
				uint cnt = _countJson(output, false);
				int elapsedTime = (HostGetTickCount() - startTime)/1000;
				if (elapsedTime < 0) elapsedTime = -1;
				string msg;
				{
					msg += "  count: " + cnt;
					msg += "\t\ttime: " + elapsedTime + " sec";
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
				string addOutput = HostExecuteProgram(qt(exePath), options + " --" + joinedUrl);
				uint addCnt = _countJson(addOutput, false);
				int elapsedTime = (HostGetTickCount() - startTime)/1000;
				if (elapsedTime < 0) elapsedTime = -1;
				if (addCnt > 0)
				{
					output += addOutput;
					cnt += addCnt;
					if (cfg.csl > 0)
					{
						string msg = "  count: " + cnt;
						msg += "\t\ttime: " + elapsedTime + " sec";
						HostPrintUTF8(msg);
					}
				}
				if (addCnt < unitIdx) break;
				if (elapsedTime < 0 || elapsedTime >= waitTime)
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
		return output;
	}
	
	string _getMetadata(array<string> urls, string options, int singleMode)
	{
		if (urls.length() == 0) return "";
		string output;
		
		int waitTime;
		if (singleMode == 1)
		{
			// for responsive websites like youtube
			waitTime = cfg.getInt("TARGET", "playlist_items_timeout");
		}
		else
		{
			waitTime = cfg.getInt("TARGET", "playlist_metadata_timeout");
			if (waitTime < 0)
			{
				cfg.setInt("TARGET", "playlist_metadata_timeout", 0);
				waitTime = 0;
			}
		}
		
		uint unitIdx = 10;
		if (waitTime == 0 || urls.length() <= unitIdx)
		{
			string joinedUrl = "";
			for (uint i = 0; i < urls.length(); i++) joinedUrl += " " + urls[i];
			
			HostIncTimeOut(2000000);
			uint startTime = HostGetTickCount();
			output = HostExecuteProgram(qt(exePath), options + " --" + joinedUrl);
			
			if (cfg.csl > 0)
			{
				uint cnt = _countJson(output, false);
				int elapsedTime = (HostGetTickCount() - startTime)/1000;
				if (elapsedTime < 0) elapsedTime = -1;
				string msg = "";
				{
					msg += "  count: " + cnt;
					msg += "\t\ttime: " + elapsedTime + " sec";
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
				string msg = (singleMode >= 2) ? "  playlist_metadata_timeout: " : "  playlist_items_timeout: ";
				msg += waitTime + " sec";
				HostPrintUTF8(msg);
			}
			uint cnt = 0;
			bool complete = false;
			uint startTime = HostGetTickCount();
			for (uint i = 0; i < urls.length(); i += unitIdx)
			{
				HostIncTimeOut(300000);
				string joinedUrl = "";
				for (uint j = i; j < i + unitIdx; j++)
				{
					joinedUrl += " " + urls[j];
					if (j >= urls.length() - 1) {complete = true; break;}
				}
				string addOutput = HostExecuteProgram(qt(exePath), options + " --" + joinedUrl);
				uint addCnt = _countJson(addOutput, false);
				int elapsedTime = (HostGetTickCount() - startTime)/1000;
				if (elapsedTime < 0) elapsedTime = -1;
				if (addCnt > 0)
				{
					output += addOutput;
					cnt += addCnt;
					if (cfg.csl > 0)
					{
						string msg = "  count: " + cnt;
						msg += "\t\ttime: " + elapsedTime + " sec";
						HostPrintUTF8(msg);
					}
				}
				if (complete) break;
				if (elapsedTime < 0 || elapsedTime >= waitTime) break;
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
		return output;
	}
	
}

YTDLP ytd;

//---------------------- END of class YTDLP ------------------------



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
		// Threshold time (millisecond) for SponsorBlock
	
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
	
	uint removeChptRange(array<dictionary> &dicsChapter, int msTime1, int msTime2, string &out chptTitle2, bool csl)
	{
		int nearTime1 = _findChptNear(dicsChapter, msTime1);
		if (nearTime1 < 0) nearTime1 = msTime1;
		int nearTime2 = _findChptNear(dicsChapter, msTime2, chptTitle2);
		if (nearTime2 < 0) nearTime2 = msTime2;
		
		uint cnt = 0;
		for (int i = 0; i < int(dicsChapter.length()); i++)
		{
			dictionary dic = dicsChapter[i];
			int time0 = parseInt(string(dic["time"]));
			if (time0 >= nearTime1 && time0 <= nearTime2)
			{
				dicsChapter.removeAt(i);
				cnt++;
				if (csl)
				{
					string title0 = string(dic["title"]);
					HostPrintUTF8("Chapter Removed:  [" + sch.formatTime(time0) + "] " + title0);
				}
				i--; continue;
			}
		}
		return cnt;
	}
	
	int _findChptNear(array<dictionary> dicsChapter, int time)
	{
		// time: millisecond
		int nearTime = -1;
		int d0 = -1;
		for (uint i = 0; i < dicsChapter.length(); i++)
		{
			dictionary dic = dicsChapter[i];
			int time0 = parseInt(string(dic["time"]));
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
	
	int _findChptNear(array<dictionary> dicsChapter, int time, string &out inheritTitle)
	{
		// time: millisecond
		int nearTime = -1;
		int d0 = -1;
		for (uint i = 0; i < dicsChapter.length(); i++)
		{
			dictionary dic = dicsChapter[i];
			int time0 = parseInt(string(dic["time"]));
			if (time0 < time + THRSH_TIME)
			{
				int d = time - time0;
				if (d < 0) d *= -1;
				if (d0 < 0 || d < d0)
				{
					d0 = d;
					inheritTitle = string(dic["title"]);
					if (d < THRSH_TIME) nearTime = time0;
				}
			}
		}
		return nearTime;
	}
	
}

SPONSOR_BLOCK sb;

//----------------------- END of class SPONSOR_BLOCK -------------------------



void OnInitialize()
{
	// Called when loading script at first
	
	if (SCRIPT_VERSION.Right(1) == "#") HostOpenConsole();	// debug version
	cfg.loadFile();
	ytd.checkFileInfo();
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
	if (noCurl == 1)
	{
		noCurl = 2;
		string msg = 
		"CURL command not found.\r\n"
		"Some features do not work if they need \"curl.exe\".\r\n"
		"Please place \"curl.exe\" in the system32 folder or in any folder accessible to the extension.";
		HostMessageBox(msg, "[yt-dlp] CAUTION: No Curl Command", 0, 1);
	}
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
	
	array<string> exts;
	{
		if (type & 0x1 > 0)	// image
		{
			array<string> extsImage = {"jpg", "jpeg", "png", "gif", "webp"};
			exts.insertAt(exts.length(), extsImage);
		}
		if (type & 0x10 > 0)	// video
		{
			array<string> extsVideo = {"avi", "wmv", "wmp", "wm", "asf", "mpg", "mpeg", "mpe", "m1v", "m2v", "mpv2", "mp2v", "ts", "tp", "tpr", "trp", "vob", "ifo", "ogm", "ogv", "mp4", "m4v", "m4p", "m4b", "3gp", "3gpp", "3g2", "3gp2", "mkv", "rm", "ram", "rmvb", "rpm", "flv", "swf", "mov", "qt", "amr", "nsv", "dpg", "m2ts", "m2t", "mts", "dvr-ms", "k3g", "skm", "evo", "nsr", "amv", "divx", "webm", "wtv", "f4v", "mxf"};
			exts.insertAt(exts.length(), extsVideo);
		}
		if (type & 0x100 > 0)	// audio
		{
			array<string> extsAudio = {"wav", "wma", "mpa", "mp2", "m1a", "m2a", "mp3", "ogg", "m4a", "aac", "mka", "ra", "flac", "ape", "mpc", "mod", "ac3", "eac3", "dts", "dtshd", "wv", "tak", "cda", "dsf", "tta", "aiff", "aif", "aifc" "opus", "amr"};
			exts.insertAt(exts.length(), extsAudio);
		}
		if (type & 0x1000 > 0)	// playlist
		{
			array<string> extsPlaylist = {"m3u8", "m3u", "asx", "pls", "wvx", "wax", "wmx", "cue", "mpls", "mpl", "xspf", "mpd", "dpl"};
				// exclude "xml", "rss"
			exts.insertAt(exts.length(), extsPlaylist);
		}
		if (type & 0x10000 > 0)	// subtitles
		{
			array<string> extsSubtitles = {"smi", "srt", "idx", "sub", "sup", "psb", "ssa", "ass", "txt", "usf", "xss.*.ssf", "rt", "lrc", "sbv", "vtt", "ttml", "srv"};
			exts.insertAt(exts.length(), extsSubtitles);
		}
		if (type & 0x100000 > 0)	// compressed
		{
			array<string> extsCompressed = {"zip", "rar", "tar", "7z", "gz", "xz", "cab", "bz2", "lzma", "rpm"};
			exts.insertAt(exts.length(), extsCompressed);
		}
		if (type & 0x1000000 > 0)	// xml, rss
		{
			array<string> extsXml = {"xml", "rss"};
			exts.insertAt(exts.length(), extsXml);
		}
	}
	
	if (exts.find(ext) >= 0) return true;
	return false;
}

bool _IsTypicalMediaExt(string path)
{
	string ext = HostGetExtension(path);
	if (_IsExtType(ext, 0x1111))
	{
		return true;
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
	pos = url.find("://", pos + 3);
	if (pos >= 0) return "";	// multiple URL
	
	string channel = sch.getRegExp(url, "(?i)^https?://www\\.youtube\\.com/@[^/?#]+");
	if (channel.empty())
	{
		channel = sch.getRegExp(url, "(?i)^https?://www\\.youtube\\.com/channel/[-\\w]+");
	}
	if (!channel.empty()) return channel;
	return "";
}

bool _IsYoutubeChannelTop(string url)
{
	string channel = _GetYoutubeChannelUrl(url);
	if (!channel.empty())
	{
		channel += "/";
		if (url.Right(1) != "/") url += "/";
		if (url.length() == channel.length()) return true;
	}
	return false;
}

string _ChangeUrlYoutubeChannelTop(string url)
{
	// YouTube channel top url -> 3 YouTube tabs
	if (_IsYoutubeChannelTop(url))
	{
		if (url.Right(1) != "/") url += "/";
		string joinedUrl = "";
		joinedUrl += url + "videos ";
		joinedUrl += url + "streams ";
		joinedUrl += url + "shorts";
		return joinedUrl;
	}
	return url;
}


string _GetYoutubeChannelTab(string url)
{
	string channel = _GetYoutubeChannelUrl(url);
	if (!channel.empty())
	{
		if(url.substr(channel.length(), 1) == "/")
		{
			string tab = url.substr(channel.length() + 1);
			if (tab.findFirstOf("/ ") < 0)
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


int _CheckBilibiliPart(string url)
{
	url.MakeLower();
	if (HostRegExpParse(url, "^https://www\\.bilibili\\.com/video/\\w+", {}))
	{
		int p = parseInt(HostRegExpParse(url, "[?&]p=(\\d+)\\b"));
		if (p > 0)
		{
			// bilibili part (?p=1 etc.)
			return p;
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
	if (_CheckBilibiliPart(url) == 0) return true;
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
		string data = HostUrlGetString(url, USER_AGENT);
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


int noCurl = 0;

string _GetHttpContent(string url, int maxTime, int range, bool isInsecure)
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
			HostPrintUTF8("\r\n http " + (range < 0 ? "header" : "content") + " -------------------");
			HostPrintUTF8(data);
			HostPrintUTF8("--------------------------\r\n");
		}
	}
	
	if (!data.empty())
	{
		// Get only the last header if data includes multiple headers with redirect
		int pos1;
		int pos2 = 0;
		do {
			pos1 = pos2;
			pos2 = sch.findRegExp(data, "(?i)\n\r?\n(HTTP)", pos1);
		} while (pos2 > pos1);
		data = data.substr(pos1);
		
	}
	
	return data;
}

string _GetHttpContent(string url, int maxTime, int range)
{
	bool isInsecure = (cfg.getInt("NETWORK", "no_check_certificates") == 1);
	return _GetHttpContent(url, maxTime, range, isInsecure);
}

string _GetHttpHeader(string url, int maxTime, bool isInsecure)
{
	return _GetHttpContent(url, maxTime, -1, isInsecure);
}

string _GetHttpHeader(string url, int maxTime)
{
	bool isInsecure = (cfg.getInt("NETWORK", "no_check_certificates") == 1);
	return _GetHttpHeader(url, maxTime, isInsecure);
}


string _GetHttpContent2(string url, bool isHeader = false)
{
	// Uses built-in function HostOpenHTTP
	
	string data;
	uintptr http = HostOpenHTTP(url, USER_AGENT);
	if (http > 0)
	{
		if (isHeader)
		{
			data = HostGetHeaderHTTP(http);
		}
		else
		{
			data = HostGetContentHTTP(http);
		}
	}
	HostCloseHTTP(http);
	
	if (cfg.csl == 3)
	{
		HostPrintUTF8("\r\n http " + (isHeader ? "header" : "content") + " -------------------");
		HostPrintUTF8(data);
		HostPrintUTF8("--------------------------\r\n");
	}
	
	return data;
}

string _GetHttpHeader2(string url)
{
	return _GetHttpContent2(url, true);
}


string _GetDataField(string data, string field, string delimiter = ":")
{
	string value = sch.getRegExp(data, "(?i)^" + field +delimiter + " ?([^\r\n]+)");
	return value;
}


int _WebsitePlaylistMode(string url)
{
	int mode = cfg.getInt("TARGET", "website_playlist_standard");
	if (mode < 0 || mode > 2) mode = 0;
	string domain = _GetUrlDomain(url);
	
	string data = cfg.getStr("TARGET", "website_playlist_each");
	data.MakeLower();
	array<string> arrData = sch.trimSplit(data, ",");
	
	for (uint i = 0; i < arrData.length(); i++)
	{
		array<string> item = sch.trimSplit(arrData[i], ":");
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
	
	if (_IsUrlSite(url, "kakao")) return false;
		// KakaoTV
	
	return true;
}


uint g_startTime = 0;

void PlaylistCancel()
{
	// Treat only online content
//HostPrintUTF8("PlaylistCancel");
	g_startTime = 0;
}

void PlayitemCancel()
{
	// Treat only online content
//HostPrintUTF8("PlayitemCancel");
	g_startTime = 0;
}

bool _CheckStartTime(uint startTime, string url)
{
	if (startTime != g_startTime)
	{
		// g_startTime has been changed because the user started another task,
		// so the current process will stop.
		if (cfg.csl > 0)
		{
			string msg;
			msg += "[yt-dlp] Process stopped by user action.";
			msg += " - \"" + url + "\"\r\n\r\n";
			HostPrintUTF8(msg);
		}
		return true;
	}
	return false;
}


bool PlaylistCheck(const string &in path)
{
	// Called when a new item is being opend from a location other than PotPlayer's playlist
//HostPrintUTF8("PlaylistCheck");
	
	string url = _ReviseUrl(path);
	
	if (!_PlayitemCheckBase(url))
	{
		// Reset g_startTime only if a local clip is opened.
		// Online content calls this function not only when being opened, but also when just reloading the thumbnail.
		if (_IsTypicalMediaExt(url)) g_startTime = 0;
		return false;
	}
	
	if (_IsUrlSite(url, "shoutcast")) return true;
	
	string ext = _GetUrlExtension(url);
	if (_IsExtType(ext, 0x1000000))	// xml/rss file
	{
		if (cfg.getInt("TARGET", "rss_playlist") == 1) return true;
		if (ext == "rss") return false;
	}
	if (_IsExtType(ext, 0x100))	// audio files
	{
		return (cfg.getInt("FORMAT", "radio_thumbnail") == 1);
	}
	if (_IsExtType(ext, 0x111011))	// other direct files
	{
		if (ext == "m3u8")
		{
			int m3u8Hls = cfg.getInt("TARGET", "m3u8_hls");
			if (m3u8Hls == 1 || m3u8Hls == 2) return true;
		}
		return false;
	}
	
	if (_IsUrlSite(url, "youtube"))
	{
		int enableYoutube = cfg.getInt("YOUTUBE", "enable_youtube");
		if (enableYoutube == 2 || enableYoutube == 3) return true;
		return false;
	}
	
	return (_WebsitePlaylistMode(url) > 0);
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
		desc = sch.cutOffString(desc, uint(titleMaxLen));
	}
	else if (titleMaxLen < 0)
	{
		cfg.setInt("FORMAT", "title_max_length", 0);
		titleMaxLen = 0;
	}
	return desc;
}


string _GetRadioThumb(string type)
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


bool _SetOrdinaryAudioThumb(array<dictionary> &out dicsEntry, string url)
{
	if (cfg.getInt("FORMAT", "radio_thumbnail") == 1)
	{
		dictionary dic;
		dic["url"] = url;
		dic["thumbnail"] = _GetRadioThumb("");
		dicsEntry.insertLast(dic);
		return true;
	}
	return false;
}


bool _CheckRss(string url, string &out imgUrl)
{
	string data = _GetHttpContent(url, 5, 2047);
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


bool _CheckUrlPlaylist(dictionary dic)
{
	int playlistSelfCnt = int(dic["playlistSelfCount"]);
	if (playlistSelfCnt > 0) return true;
	
	string url = string(dic["url"]);
	if (_IsUrlSite(url, "youtube"))
	{
		if (sch.findI(url, "?list=") > 0) return true;
		string channel = _GetYoutubeChannelUrl(url);
		if (!channel.empty()) return true;
	}
	
	return false;
}


string _GetDataValueString(string data, string key)
{
	key = sch.escapeReg(key);
	string str = HostRegExpParse(data, "\"" + key +"\":\\s?\"([^\"]+)\"");
	return str;
}

int _GetDataValueInt(string data, string key)
{
	key = sch.escapeReg(key);
	int num = parseInt(HostRegExpParse(data, "\"" + key +"\":\\s?(-?\\d+)"));
	return num;
}


array<string> _RemoveEntryYoutubeTab(array<string> entries)
{
	array<string> outEntries = {};
	uint n = 0;
	for (uint i = 0; i < entries.length(); i++)
	{
		string url = _GetDataValueString(entries[i], "webpage_url");
		if (!_GetYoutubeChannelTab(url).empty())
		{
			n++;
		}
		else
		{
			outEntries.insertLast(entries[i]);
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
	return outEntries;
}

array<string> _MakeUrlArrayAll(array<string> entries)
{
	array<string> urls = {};
	for (uint i = 0; i < entries.length(); i++)
	{
		string url = _GetDataValueString(entries[i], "webpage_url");
		if (!url.empty()) urls.insertLast(url);
	}
	return urls;
}

string _MakeUrlJoinAll(array<string> entries)
{
	string joinedUrl = "";
	for (uint i = 0; i < entries.length(); i++)
	{
		string url = _GetDataValueString(entries[i], "webpage_url");
		if (!url.empty())
		{
			if (!joinedUrl.empty()) joinedUrl += " ";
			joinedUrl += url;
		}
	}
	return joinedUrl;
}

array<string> _MakeUrlArrayMetadata1(array<dictionary> dicsEntry, array<uint> &inout arrIdx)
{
	array<string> urls = {};
	arrIdx = {};
	for (uint i = 0; i < dicsEntry.length(); i++)
	{
		bool make = false;
		if (string(dicsEntry[i]["title"]).empty())
		{
			make = true;
		}
		else if (string(dicsEntry[i]["thumbnail"]).empty())
		{
			make = true;
		}
		/*
		else if (string(dicsEntry[i]["duration"]).empty())
		{
			make = true;
		}
		*/
		else if (_CheckUrlPlaylist(dicsEntry[i]))
		{
			make = true;
		}
		
		if (make)
		{
			urls.insertLast(string(dicsEntry[i]["url"]));
			arrIdx.insertLast(i);
		}
	}
	return urls;
}

array<string> _MakeUrlArrayMetadata2(array<dictionary> dicsEntry, array<uint> &inout arrIdx)
{
	array<string> urls = {};
	arrIdx = {};
	for (uint i = 0; i < dicsEntry.length(); i++)
	{
		if (!string(dicsEntry[i]["title"]).empty())
		{
			if (_CheckUrlPlaylist(dicsEntry[i]))
			{
				urls.insertLast(string(dicsEntry[i]["url"]));
				arrIdx.insertLast(i);
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

dictionary _PlaylistParse(string json, bool forcePlaylist, string imgUrl)
{
	if (json.empty()) return {};
	
	dictionary dic;
	JsonReader reader;
	JsonValue root;
	if (reader.parse(json, root) && root.isObject())
	{
		string url = _GetJsonValueString(root, "url");
		if (url.empty()) url = _GetJsonValueString(root, "original_url");
		if (url.empty()) url = _GetJsonValueString(root, "webpage_url");
		if (url.empty()) return {};
		{
			// Remove parameter added by yt-dlp.
			int pos = url.find("#__youtubedl");
			if (pos > 0) url = url.Left(pos);
		}
		dic["url"] = url;
		
		string extractor = _GetJsonValueString(root, "extractor_key");
		if (extractor.empty()) extractor = _GetJsonValueString(root, "extractor");
		if (extractor.empty()) return {};
		dic["extractor"] = extractor;
		
		string ext = _GetJsonValueString(root, "ext");
		bool isAudio = _IsExtType(ext, 0x100);
		if (isAudio)
		{
			forcePlaylist = true;	// for setting thumbnail
		}
		
		int playlistIdx = _GetJsonValueInt(root, "playlist_index");
		if (playlistIdx < 1)
		{
			if (!forcePlaylist)
			{
				return {};
			}
			playlistIdx = 0;
		}
		dic["playlist_index"] = playlistIdx;
		int playlistCnt = _GetJsonValueInt(root, "playlist_count");
		if (playlistCnt > 0) dic["playlist_count"] = playlistCnt;
		
		string baseName = _GetJsonValueString(root, "webpage_url_basename");
		if (baseName.empty()) return {};
		string ext2 = HostGetExtension(baseName);
		
		string title = _GetJsonValueString(root, "title");
		if (!title.empty())
		{
			if (baseName != title + ext2)
			{
				// Consider title as empty if yt-dlp cannot get a substantial title.
				// Prevent PotPlayer from overwriting the edited title in the playlist panel.
				title = _ReviseWebString(title);
				title = _CutOffString(title);
				dic["title"] = title;
			}
		}
		string playlistTitle = _GetJsonValueString(root, "playlist_title");
		if (!playlistTitle.empty())
		{
			if (baseName != playlistTitle + ext2)
			{
				playlistTitle = _ReviseWebString(playlistTitle);
				playlistTitle = _CutOffString(playlistTitle);
				dic["playlist_title"] = playlistTitle;
			}
		}
		
		string thumb = _GetJsonValueString(root, "thumbnail");
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
						thumb = _GetJsonValueString(jThumbmax, "url");
					}
				}
			}
			if (thumb.empty())
			{
				thumb = imgUrl;
				if (thumb.empty())
				{
					if (isAudio)
					{
						if (_isGeneric(extractor))
						{
							if (cfg.getInt("FORMAT", "radio_thumbnail") == 1)
							{
								thumb = _GetRadioThumb("");
							}
						}
					}
				}
			}
		}
		if (!thumb.empty()) dic["thumbnail"] = thumb;
		
		string duration = _GetJsonValueString(root, "duration_string");
		if (duration.empty())
		{
			int secDuration = _GetJsonValueInt(root, "duration");
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
		if (!duration.empty()) dic["duration"] = duration;
		
		string author = _GetJsonValueString(root, "channel");
		if (author.empty())
		{
			author = _GetJsonValueString(root, "uploader");
			if (author.empty())
			{
				author = _GetJsonValueString(root, "uploader_id");
				if (author.Left(1) == "@")	// youtube
				{
					author = author.substr(1);
					author.replace("_", " ");
				}
				if (author.empty())
				{
					author = _GetJsonValueString(root, "atrist");
				}
			}
		}
		if (!author.empty())
		{
			author = _ReviseWebString(author);
			dic["author"] = author + " @" + extractor;
		}
		
	}
	return dic;
}

string _GetPageTitle(string url)
{
	string data = HostUrlGetString(url, USER_AGENT);
	//string data = _GetHttpContent(url, 3, 8000);
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


string _PlaylistParseNotExtract(string url, dictionary &inout MetaData)
{
	if (cfg.csl > 0)
	{
		HostPrintUTF8("\r\n[yt-dlp] Counting playlist items... - \"" + url + "\"" );
	}
	uint startTime = HostGetTickCount();
	
	string thumb = string(MetaData["thumbnail"]);
	
	string extractor;
	string playlistTitle;
	uint playlistSelfCnt = 0;
	string joinedUrl = _ChangeUrlYoutubeChannelTop(url);
	if (joinedUrl != url)
	{
		// YouTube channel top
		extractor = "Youtube";
		playlistTitle = _GetPageTitle(url);
		playlistSelfCnt = ytd.countItemsAll(joinedUrl);
	}
	else if (_IsYoutubeTabPlaylistType(url) && cfg.getInt("YOUTUBE", "keep_tab_playlist") != 1)
	{
		// Count all nested playlists in a YouTube tab
		array<string> entries = ytd.exec2({url}, 0);
		if (entries.length() > 0)
		{
			dictionary dic = _PlaylistParse(entries[0], true, "");
			
			extractor = "Youtube";
			
			playlistTitle = string(dic["playlist_title"]);
			if (playlistTitle.empty())
			{
				playlistTitle = _GetPageTitle(url);
			}
			
			joinedUrl = _MakeUrlJoinAll(entries);
			playlistSelfCnt = ytd.countItemsAll(joinedUrl);
		}
	}
	else
	{
		array<string> entries = ytd.exec2({url}, 3);
		if (entries.length() == 1)
		{
			dictionary dic = _PlaylistParse(entries[0], true, "");
			
			extractor = string(dic["extractor"]);
			
			playlistTitle = string(dic["playlist_title"]);
			if (playlistTitle.empty())
			{
				playlistTitle = _GetPageTitle(url);
			}
			
			playlistSelfCnt = int(dic["playlist_count"]);
		}
	}
	
	if (extractor.empty()) return "";
	
	int elapsedTime = (HostGetTickCount() - startTime)/1000;
	if (elapsedTime < 0) elapsedTime = -1;
	if (cfg.csl > 0)
	{
		string msg;
		msg += "  count: " + playlistSelfCnt;
		msg += "\t\ttime: " + elapsedTime + " sec";
		msg += "\r\n";
		msg += (playlistSelfCnt == 0 || elapsedTime < 0) ? "  Failed to get." : "  Complete.";
		msg += "\r\n\r\n";
		HostPrintUTF8(msg);
	}
	
	if (thumb.empty())
	{
		array<string> entries = ytd.exec2({url}, -1);
		if (entries.length() == 1)
		{
			dictionary dic = _PlaylistParse(entries[0], true, "");
			thumb = string(dic["thumbnail"]);
		}
	}
	
	MetaData["url"] = url;
	MetaData["webUrl"] = url;
	
	if (!playlistTitle.empty())
	{
		playlistTitle = _ReviseWebString(playlistTitle);
		playlistTitle = _CutOffString(playlistTitle);
		MetaData["title"] = playlistTitle;
	}
	
	if (playlistSelfCnt > 0)
	{
		MetaData["playlistSelfCount"] = playlistSelfCnt;
	}
	
	string note = "";
	{
		note += "<Playlist";
		if (playlistSelfCnt > 0) note += ": " + playlistSelfCnt;
		note += ">";
		if (!_isGeneric(extractor)) note += " @" + extractor;
	}
	MetaData["author"] = note;
	
	MetaData["duration"] = "";
	
	if (thumb.empty()) thumb = url;
	MetaData["thumbnail"] = thumb;
	
	return thumb;
}


array<dictionary> PlaylistParse(const string &in path)
{
	// Called after PlaylistCheck if it returns true
//HostPrintUTF8("PlaylistParse - " + path);
	
	uint startTime = HostGetTickCount();
	g_startTime = startTime;
	
	if (cfg.csl > 0) HostOpenConsole();
	
	array<dictionary> dicsEntry;
	
	string plUrl = _ReviseUrl(path);
	
	if (_IsUrlSite(plUrl, "shoutcast"))
	{
		if (cfg.getInt("TARGET", "shoutcast_playlist") == 1)
		{
			shoutpl.passPlaylist(plUrl, dicsEntry);
			if (cfg.csl > 0)
			{
				HostPrintUTF8("[yt-dlp] Shoutcast playlist was not expanded according to the [shoutcast_playlist] setting. - " + ytd.qt(plUrl) + "\r\n\r\n");
			}
		}
		else
		{
			shoutpl.extractPlaylist(plUrl, dicsEntry);
		}
		return dicsEntry;
	}
	
	if (_GetUrlExtension(plUrl) == "m3u8")
	{
		if (cfg.getInt("TARGET", "m3u8_hls") == 1 && _CheckM3u8Hls(plUrl))
		{
			return {};
		}
	}
	
	string httpHead = _GetHttpHeader(plUrl, 5);
	
	if (_CheckRadioServer(httpHead))
	{
		if (_SetOrdinaryAudioThumb(dicsEntry, plUrl))
		{
			return dicsEntry;
		}
		return {};
	}
	
	string fileType = _GetFileType(httpHead);
	if (!fileType.empty())
	{
		if (fileType == "audio")
		{
			if (_SetOrdinaryAudioThumb(dicsEntry, plUrl))
			{
				return dicsEntry;
			}
		}
		return {};
	}
	
	if (_CheckStartTime(startTime, path)) return {};
	
	int playlistMode = _WebsitePlaylistMode(plUrl);
	
	if (playlistMode == 0)
	{
		// particular case with YouTube (need no actual extracting)
		
		dictionary dic;
		_PlaylistParseNotExtract(plUrl, dic);
		
		if (_CheckStartTime(startTime, path)) return {};
		
		dicsEntry.insertLast(dic);
		return dicsEntry;
	}
	
	// Execute yt-dlp
	array<string> entries = ytd.exec1(plUrl, playlistMode, "");
	if (entries.length() == 0) return {};
	
	if (_IsYoutubeTabPlaylistType(plUrl))
	{
		entries = _RemoveEntryYoutubeTab(entries);
		if (cfg.getInt("YOUTUBE", "keep_tab_playlist") != 1)
		{
			// Extract all nested playlists
			array<string> urls = _MakeUrlArrayAll(entries);
			entries = ytd.exec2(urls, 0);
		}
	}
	
	if (_CheckStartTime(startTime, path)) return {};
	
	bool forcePlaylist = false;
	bool isYoutube = _IsUrlSite(plUrl, "youtube");
	if (isYoutube) forcePlaylist = true;;
		// For YouTube, this extension always treats a URL as a playlist
		// to prevent the built-in YouTube extension from changing the playlist state.
		// If a URL refers to both a video and a playlist
		// (e.g., https://www.youtube.com/watch?v=XXXXX&list=YYYYY),
		// this extension can ignore the playlist using the --no-playlist option.
		// and treats the URL as a playlist that contains only the single video.
	
	bool isRss = false;
	string imgUrl;
	if (_IsExtType(_GetUrlExtension(plUrl), 0x1000000))	// xml/rss file
	{
		if (_CheckRss(plUrl, imgUrl))
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
	
	for (uint i = 0; i < entries.length(); i++)
	{
		dictionary dic = _PlaylistParse(entries[i], forcePlaylist, imgUrl);
		dicsEntry.insertLast(dic);
	}
	
	uint errCnt = 0;
	array<uint> arrIdx = {};
	array<string> urls = _MakeUrlArrayMetadata1(dicsEntry, arrIdx);
	if (urls.length() > 0)
	{
		int singleMode = 1;
		bool noTitle = string(dicsEntry[0]["title"]).empty();
		bool isYoutubeShort = (isYoutube && urls[0].find("/shorts/") > 0);
		if (noTitle || isYoutubeShort) singleMode = 2;
		if (_IsPotentialBiliPart(urls[0])) singleMode = 3;
		
		array<string> errIds = {};
		array<string> _entries = ytd.exec2(urls, singleMode, errIds);
		
		if (_CheckStartTime(startTime, path)) return {};
		
		errCnt = errIds.length();	// errCnt = 0 if YouTube
		
		for (uint i = 0; i < _entries.length(); i++)
		{
			dictionary dic1 = _PlaylistParse(_entries[i], true, imgUrl);
			dictionary @dic0 = dicsEntry[arrIdx[i]];
			while (dic0 !is null)
			{
				if (_MatchIds(string(dic0["url"]), errIds))
				{
					dicsEntry.removeAt(arrIdx[i]);
					arrIdx.removeAt(i);
					for (uint j = i; j < arrIdx.length(); j++)
					{
						arrIdx[j] = arrIdx[j] - 1;
					}
					@dic0 = dicsEntry[arrIdx[i]];
					continue;
				}
				break;
			}
			
			string extractor = string(dic1["extractor"]);
			
			int playlistIdx = int(dic1["playlist_index"]);
			bool selfPlaylist = (playlistIdx > 0);
			if (selfPlaylist)	// for playlist
			{
				int playlistSelfCnt = int(dic1["playlist_count"]);
				if (playlistSelfCnt > 0)
				{
					dic0["playlistSelfCount"] = playlistSelfCnt;
				}
				
				string note;
				{
					note += "<Playlist";
					if (playlistSelfCnt > 0)
					{
						note += ": " + playlistSelfCnt;
					}
					note += ">";
					if  (!_isGeneric(extractor))
					{
						note += " @" + extractor;
					}
				}
				dic0["author"] = note;
			}
			else
			{
				if (string(dic0["author"]).empty())
				{
					string author = string(dic1["author"]);
					if  (!author.empty())
					{
						dic0["author"] = author;
					}
				}
			}
			
			if (string(dic0["title"]).empty())
			{
				string title;
				if (selfPlaylist)
				{
					title = string(dic1["playlist_title"]);
				}
				else
				{
					title = string(dic1["title"]);
				}
				if (!title.empty())
				{
					dic0["title"] = title;
				}
			}
			
			if (string(dic0["thumbnail"]).empty())
			{
				string thumb = string(dic1["thumbnail"]);
				if (!thumb.empty())
				{
					dic0["thumbnail"] = thumb;
				}
				else
				{
					dic0["thumbnail"] = urls[i];
				}
			}
			
			if (string(dic0["duration"]).empty())
			{
				if (!selfPlaylist)
				{
					string duration = string(dic1["duration"]);
					if (!duration.empty())
					{
						dic0["duration"] = duration;
					}
				}
			}
			else
			{
				if (selfPlaylist)
				{
					dic0["duration"] = "";
				}
			}
		}
		
		// Remove items, matadata of which has not been collected yet
		if (cfg.getInt("TARGET", "playlist_without_metadata") != 1)
		{
			for (int i = 0; i < int(dicsEntry.length()); i++)
			{
				if (string(dicsEntry[uint(i)]["title"]).empty())
				{
					dicsEntry.removeAt(i);
					i--; continue;
				}
			}
		}
		
		// Get BilibiliPart thumbnails
		if (singleMode == 3)
		{
			array<uint> arrIdx2 = {};
			array<string> urls2 = _MakeUrlArrayMetadata2(dicsEntry, arrIdx2);
			if (urls2.length() > 0)
			{
				array<string> _entries2 = ytd.exec2(urls2, -1);
				
				if (_CheckStartTime(startTime, path)) return {};
				
				for (uint i = 0; i < _entries2.length(); i++)
				{
					dictionary dic2 = _PlaylistParse(_entries2[i], true, "");
					dictionary @dic0 = dicsEntry[arrIdx2[i]];
						
					string thumb = string(dic2["thumbnail"]);
					if (!thumb.empty()) dic0["thumbnail"] = thumb;
				}
			}
		}
	}
	
	// Remove unavailable videos on YouTube
	if (isYoutube)
	{
		errCnt = 0;
		for (int i = 0; i < int(dicsEntry.length()); i++)
		{
			string thumb = string(dicsEntry[uint(i)]["thumbnail"]);
			if (thumb.find("no_thumbnail.") >= 0)
			{
				errCnt++;
				dicsEntry.removeAt(i);
				i--; continue;
			}
		}
	}
	
	if (dicsEntry.length() > 0)
	{
		// Keep the hash of yt-dlp.exe, which works without issues.
		if (!ytd.tmpHash.empty() && ytd.tmpHash != cfg.getStr("MAINTENANCE", "ytdlp_hash"))
		{
			cfg.setStr("MAINTENANCE", "ytdlp_hash", ytd.tmpHash);
		}
		ytd.backupExe();
	}
	
	if (cfg.csl > 0)
	{
		string msg;
		msg += "\r\n";
		if (errCnt > 0)
		{
			msg += "  unavailable count: " + errCnt + "\r\n";
			msg += "  available count: " +  dicsEntry.length() + "\r\n";
		}
		else
		{
			msg += "  total count: " + dicsEntry.length() + "\r\n";
		}
		HostPrintUTF8(msg);
	}
	
	return dicsEntry;
}


bool PlayitemCheck(const string &in path)
{
	// Called when an item is being opened after PlaylistCheck or PlaylistParse
//HostPrintUTF8("PlayitemCheck");
	
	string url = _ReviseUrl(path);
	url.MakeLower();
	
	if (!_PlayitemCheckBase(url))
	{
		// Reset g_startTime only if a local clip is opened.
		// Online content calls this function not only when being opened, but also when just reloading the thumbnail.
		if (_IsTypicalMediaExt(url)) g_startTime = 0;
		return false;
	}
	
	string ext = _GetUrlExtension(url);
	if (ext == "rss") return false;
	if (_IsExtType(ext, 0x111000))	// playlist or other files
	{
		if (ext == "m3u8" || ext == "txt")
		{
			int m3u8Hls = cfg.getInt("TARGET", "m3u8_hls");
			if (m3u8Hls == 1 || m3u8Hls == 2) return true;
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

bool _RunAsync(string exePath, string para)
{
	// exePath / para: within the ASCII code
	bool ret = false;
	uintptr hShell = HostLoadLibrary("shell32.dll");
//HostPrintUTF8("hShell: " + hShell);
	if (hShell > 0)
	{
		uintptr pShellExecuteA = HostGetProcAddress(hShell, "ShellExecuteA");
		if (pShellExecuteA > 0)
		{
			uintptr exePtr = HostString2UIntPtr(exePath);
			uintptr paraPtr = HostString2UIntPtr(para);
			uintptr opPtr  = HostString2UIntPtr("open");
			HostCallProcAsync(pShellExecuteA,"PPPPPI",
				0,			// P: HWND = 0
				opPtr,		// P: lpOperation
				exePtr,		// P: lpFile
				paraPtr,	// P: lpParameters
				0,			// P: lpDirectory
				1			// I: nShowCmd = SW_SHOWNORMAL
			);
			ret = true;
		}
		HostFreeLibrary(hShell);
	}
	if (cfg.csl > 0 && !ret)
	{
		HostPrintUTF8("[yt-dlp] Cannot use the win32 API library.");
	}
	return ret;
}

void _PotPlayerAddList(string url, int mode)
{
	string potplayerExe = HostGetExecuteFolder() + "\\";
	potplayerExe += "PotPlayerMini" + (HostIsWin64() ? "64" : "") + ".exe";
	string options;
	options = "\"" + url + "\"";
	options += " /current";
	if (mode == 0) options += " /insert";
	else if (mode == 1) options += " /add";
	else if (mode == -1) options += " /autoplay";
	
	if (!_RunAsync(potplayerExe, options))
	{
		HostExecuteProgram(potplayerExe, options);
	}
}

string _FormatDate(string date)
{
	// Thu, 04 Sep 2025 21:34:00 GMT -> 20250904
	// not consider time zone
	string year, month, day;
	array<string> arrMonth = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
	array<dictionary> match;
	if (sch.regExpParse(date, "(?i)\\w{3}, (\\d{2}) (\\w{3}) (\\d{4})\\b", match, 0) >= 0)
	{
		day = string(match[1]["str"]);
		month = string(match[2]["str"]);
		year = string(match[3]["str"]);
		month = formatInt(sch.findI(arrMonth, month) + 1);
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


bool _isGeneric(string extractor)
{
	if (sch.findRegExp(extractor, "(?i)(generic|html5)") == 0)
	{
		return true;
	}
	return false;
}

bool _TitleAuthorSites(string extractor)
{
	// These sites always add the author name to the title top
	array<string> sites = {"twitter"};
	if (sites.find(extractor.MakeLower()) >= 0)
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
	
	desc = sch.decodeEntityRefs(desc);
	desc = sch.decodeNumericCharRefs(desc);
	desc = sch.decodeUTF16BE(desc);
	
	return desc;
}


bool _MatchAutoSubLangs(string code)
{
	if (code.empty()) return false;
	
	for (uint i = 0; i < cfg.autoSubLangs.length(); i++)
	{
		string findCode = cfg.autoSubLangs[i];
		if (sch.findRegExp(code, "(?i)^" + sch.escapeReg(findCode) + "\\b") >= 0)
		{
			// If findCode is "zh", both "zh-Hans" and "zh-Hant" are matched.
			return true;
		}
	}
	return false;
}

bool _SelectAutoSub(string code, array<dictionary> &dicsSub)
{
	bool match = false;
	
	int pos = sch.findI(code, "-orig");
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
	for (int i = 0; i < int(dicsSub.length()); i++)
	{
		string existCode = string(dicsSub[i]["langCode"]);
		{
			if (code == existCode) return false;
			if (code + "-orig" == existCode) return false;
			if (code == existCode + "-orig")
			{
				string kind = string(dicsSub[i]["kind"]);
				if (kind == "asr")
				{
					dicsSub.removeAt(i);
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
	// only on YouTube
	// Return true if note is possible to be a language name
	
	if (false)
	{
		// This is not available for some languages such as Polish.
		note = sch.omitDecimal(note, ",");
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
		array<string> words = note.split(",");
		if (words.length() > 2)
		{
//HostPrintUTF8("words[1]: " + words[1]);
			for (uint i = 0; i < qualities.length(); i++)
			{
				if (words[1] == " " + qualities[i])
				{
					return words[0];
				}
			}
		}
	}
	
	return "";
}


bool _HideDubbed(string audioCode, string va, bool isDefault)
{
	// only for Youtube
	
	int dubbedFilter = cfg.getInt("YOUTUBE", "dubbed_filter");
	
	if (dubbedFilter == 1)
	{
		if (va == "va" || va == "a")
		{
			if (!isDefault)
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
			if (!isDefault)
			{
				return true;
			}
		}
	}
	
	return false;
}


void _FillAudioName(array<dictionary> &QualityList)
{
	// only on YouTube
	
	for (int i = 0; i < int(QualityList.length()); i++)
	{
		string code1 = string(QualityList[i]["audioCode"]);
		
		string va = string(QualityList[i]["va"]);
		bool audioIsDefault = bool(QualityList[i]["audioIsDefault"]);
		if (_HideDubbed(code1, va, audioIsDefault))
		{
			QualityList.removeAt(i);
			i--; continue;
		}
		
		if (!code1.empty())
		{
			string name = string(QualityList[i]["audioName"]);
			if (name.empty())
			{
				// missing audioName
				for (int j = 0; j < int(QualityList.length()); j++)
				{
					if (j == i) continue;
					string code2 = string(QualityList[j]["audioCode"]);
					if (code2 == code1)
					{
						name = string(QualityList[j]["audioName"]);
						if (!name.empty()) break;
					}
				}
				if (!name.empty())
				{
					QualityList[i]["audioName"] = name;
				}
				else
				{
					QualityList[i]["audioName"] = code1;
				}
			}
		}
	}
}


void _FillVR(array<dictionary> &QualityList, int type3D)
{
	for (uint i = 0; i < QualityList.length(); i++)
	{
		string va = string(QualityList[i]["va"]);
		if (va == "v" || va == "va")
		{
			if (!bool(QualityList[i]["is360"]))
			{
				//QualityList[i]["is360"] = true;
			}
			if (type3D > 0)
			{
				if (int(QualityList[i]["type3D"]) == 0)
				{
					//QualityList[i]["type3D"] = type3D;
				}
			}
		}
	}
}


bool __IsQualityDuplicate(dictionary dic1, dictionary dic2)
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
		
		if (dic1.exists(key) != dic2.exists(key)) return false;
		
		if (dic1.exists(key))
		{
			string strVal1 = string(dic1[key]);
			string strVal2 = string(dic2[key]);
			if (strVal1.empty() != strVal2.empty()) return false;
			
			if (!strVal1.empty())
			{
				if (strVal1 != strVal2)
				{
					if (key == "quality")
					{
						// If the difference of bitrate is small, two audio quolities are considered the same.
						if (strVal1.Right(1) != "K" || strVal2.Right(1) != "K") return false;
						float fltVal1 = parseFloat(strVal1);
						float fltVal2 = parseFloat(strVal2);
						float d = fltVal1 - fltVal2;
						if (d < 0) d *= -1;
						if (d > 40) return false;
					}
					else
					{
						return false;
					}
				}
			}
			else
			{
				float fltVal1 = float(dic1[key]);
				float fltVal2 = float(dic2[key]);
				if (fltVal1 != fltVal2) return false;
			}
		}
	}
	
	return true;
}


bool _IsQualityDuplicate(dictionary dic, array<dictionary> dics)
{
	for (int i = dics.length() - 1; i >= 0; i--)
	{
		if (__IsQualityDuplicate(dic, dics[i])) return true;
	}
	return false;
}


string _GetJsonValueString(JsonValue json, string key)
{
	string str = "";
	if (!key.empty())
	{
		JsonValue jValue = json[key];
		if (jValue.isString()) str = jValue.asString();
	}
	return str;
}


float _GetJsonValueFloat(JsonValue json, string key)
{
	float f = -10000;
	if (!key.empty())
	{
		JsonValue jValue = json[key];
		if (jValue.isFloat()) f = jValue.asFloat();
	}
	return f;
}


int _GetJsonValueInt(JsonValue json, string key)
{
	int i = -10000;
	if (!key.empty())
	{
		JsonValue jValue = json[key];
		if (jValue.isInt()) i = jValue.asInt();
	}
	return i;
}


bool _GetJsonValueBool(JsonValue json, string key)
{
	bool b = false;
	if (!key.empty())
	{
		JsonValue jValue = json[key];
		if (jValue.isBool()) b = jValue.asBool();
	}
	return b;
}


bool _CheckProtocol(string protocol)
{
	if (protocol.Left(4) == "http") return false;
	if (protocol.Left(4) == "m3u8") return false;
	if (protocol == "fc2_live") return false;
	return true;
}


bool _CheckM3u8Hls(string url)
{
	string data = _GetHttpContent(url, 3, 63);
	if (!data.empty())
	{
		if (data.find("\n#EXT-X-") >= 0)
		{
			return true;	// HLS
		}
		data.replace("\r", ""); data.replace("\n", "");
		if (!data.empty())
		{
			return false;	// non-HLS possibly
		}
	}
	return true;	// potential HLS
}


bool _CheckRadioServer(string httpHead)
{
	if (!httpHead.empty())
	{
		string title = _GetDataField(httpHead, "icy-name");
		if (!title.empty()) return true;
		string server = _GetDataField(httpHead, "Server");
		if (sch.findI(server, "icecast") >= 0) return true;
	}
	return false;
}

bool _GetRadioInfo(dictionary &inout MetaData, string httpHead, string url)
{
	if (httpHead.empty()) return false;
	
	string server = _GetDataField(httpHead, "Server");
	if (sch.findI(server, "icecast") >= 0)
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
		string data = _GetHttpContent(url2, 5, 2047);
		if (!data.empty())
		{
			data = HostRegExpParse(data, "<annotation>([^<]+)</annotation>");
			string title = _GetDataField(data, "Stream Title");
			if (!title.empty())
			{
				if (server.empty()) server = "IcecastCh";
				string _s;
				if ((!MetaData.get("title", _s)) || _s.empty())
				{
					title = _ReviseWebString(title);
					title = _CutOffString(title);
					MetaData["title"] = title;
					MetaData["author"] = title + " @" +server;
						// The station name is kept in the author field
				}
				string genre = _GetDataField(data, "Stream Genre");
				string desc = _GetDataField(data, "Stream Description");
				string content;
				if (!genre.empty()) content = "{" + genre + "}";
				if (!desc.empty()) content = (!content.empty() ? " " : "") + desc;
				if (!content.empty())
				{
					content = _ReviseWebString(content);
					MetaData["content"] = content;
				}
				int viewCount = parseInt(_GetDataField(data, "Current Listeners"));
				if (viewCount > 0)
				{
					MetaData["viewCount"] = viewCount;
				}
				if (cfg.getInt("FORMAT", "radio_thumbnail") == 1)
				{
					MetaData["thumbnail"] = _GetRadioThumb("icecast");
				}
				return true;
			}
		}
		
		// url3: baseUrl + "/status-json.xsl"	// for Icecast
	}
	
	// Metadata from icy- header
	string title = _GetDataField(httpHead, "icy-name");
	if (!title.empty())
	{
		string _s;
		if ((!MetaData.get("title", _s)) || _s.empty())
		{
			title = _ReviseWebString(title);
			title = _CutOffString(title);
			MetaData["title"] = title;
			MetaData["author"] = title + " @" +server;
				// The station name is kept in the author field
		}
		string genre = _GetDataField(httpHead, "icy-genre");
		string desc = _GetDataField(httpHead, "icy-description");
		string content;
		if (!genre.empty()) content = "{" + genre + "}";
		if (!desc.empty()) content = (!content.empty() ? " " : "") + desc;
		if (!content.empty())
		{
			content = _ReviseWebString(content);
			MetaData["content"] = content;
		}
		int viewCount = parseInt(_GetDataField(httpHead, "icy-listeners"));
		if (viewCount > 0)
		{
			MetaData["viewCount"] = viewCount;
		}
		if (cfg.getInt("FORMAT", "radio_thumbnail") == 1)
		{
			MetaData["thumbnail"] = _GetRadioThumb(server == "IcecastCh" ? "icecast" : "shoutcast");
		}
		return true;
	}
	
	return false;
}


void _SetFileInfo(dictionary &inout MetaData, string url, string httpHead, bool setThumb)
{
	MetaData["url"] = url;
	
	string domain = _GetUrlDomain(url);
	if (!domain.empty()) MetaData["author"] = domain;
	
	string date = _GetDataField(httpHead, "Last-Modified");
	if (date.empty()) date = _GetDataField(httpHead, "Date");
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
	
	int contLen = parseInt(_GetDataField(httpHead, "Content-Length"));
	if (contLen > 100)
	{
		string contType = _GetDataField(httpHead, "Content-Type");
		if (!contType.empty())
		{
			if (sch.findI(contType, "image/") >= 0)
			{
				return "image";
			}
			else if (sch.findI(contType, "video/") >= 0)
			{
				array<string> arrVideo = {"mp4", "webm", "ogg", "mpeg"};
				if (sch.findI(arrVideo, contType.substr(6)) >= 0)
				{
					return "video";
				}
			}
			else if (sch.findI(contType, "audio/") >= 0)
			{
				array<string> arrAudio = {"mpeg", "aac", "aacp", "flac", "ogg", "opus", "webm", "wav", "x-wav"};
				if (sch.findI(arrAudio, contType.substr(6)) >= 0)
				{
					return "audio";
				}
			}
			else if (sch.findI(contType, "application/") >= 0)
			{
				// media containers
				if (sch.findI(contType, "/ogg") >= 0) return "audio";
				if (sch.findI(contType, "/mp4") >= 0) return "video/audio";
				if (sch.findI(contType, "/webm") >= 0) return "video/audio";
				if (sch.findI(contType, "/mxf") >= 0) return "video/audio";
			}
		}
	}
	return "";
}


string _ReviseCookies(string cookies)
{
	if (cookies.empty()) return "";
	cookies += "; ";
	array<string> eraseKeys = {"Domain", "Path", "Secure", "Expires"};
	for (uint i = 0; i < eraseKeys.length(); i++)
	{
		int pos = 0;
		while (true)
		{
			string str;
			pos = sch.findRegExp(cookies, eraseKeys[i] + "[^;]*; ", str, pos);
			if (pos >= 0)
			{
				cookies.erase(pos, str.length());
				continue;
			}
			break;
		}
	}
	if (cookies.Right(1) == " ") cookies = cookies.Left(cookies.length() - 1);
	if (cookies.Right(1) == ";") cookies = cookies.Left(cookies.length() - 1);
	return cookies;
}


void _SetHeaders(string url, JsonValue jFormat, int &inout needPlaybackCookie)
{
	string cookies = _GetJsonValueString(jFormat, "cookies");
	//cookies = _ReviseCookies(cookies);
	if (!cookies.empty())
	{
		if (needPlaybackCookie == 0) needPlaybackCookie = 1;
	}
	else
	{
		needPlaybackCookie = -1;
	}
	
	string headers;
	JsonValue jHeaders = jFormat["http_headers"];
	bool isBigHeader = false;
		// BigHeader includes Referer and Cookie in PotPlayer versions earlier than 260114.
	if (jHeaders.isObject())
	{
		string userAgent = _GetJsonValueString(jHeaders, "User-Agent");
		if (!userAgent.empty())
		{
//HostPrintUTF8("userAgent: " + userAgent);
			if (isBigHeader)
			{
				headers += "User-Agent: " + userAgent + "\r\n";
			}
			else
			{
				HostSetUrlUserAgentHTTP(url, userAgent);
			}
		}
		
		string referer = _GetJsonValueString(jHeaders, "Referer");
		if (!referer.empty())
		{
//HostPrintUTF8("referer: " + referer);
			if (isBigHeader)
			{
				headers += "Referer: " + referer + "\r\n";
			}
			else
			{
				HostSetUrlRefererHTTP(url, referer);
			}
		}
		
		string accept = _GetJsonValueString(jHeaders, "Accept");
		if (!accept.empty())
		{
			headers += "Accept: " + accept + "\r\n";
		}
		
		string acceptLanguage = _GetJsonValueString(jHeaders, "Accept-Language");
		if (!acceptLanguage.empty())
		{
			headers += "Accept-Language: " + acceptLanguage + "\r\n";
		}
		
		string secFetchMode = _GetJsonValueString(jHeaders, "Sec-Fetch-Mode");
		if (!secFetchMode.empty())
		{
			headers += "Sec-Fetch-Mode: " + secFetchMode + "\r\n";
		}
	}
	if (!cookies.empty())
	{
		//cookies = sch.escapeQuote(cookies);
//HostPrintUTF8("cookies: " + cookies);
		if (isBigHeader)
		{
			headers += "Cookie: " + cookies + "\r\n";
		}
		else
		{
			HostSetUrlCookieHTTP(url, cookies);
		}
	}
	if (!headers.empty())
	{
//HostPrintUTF8("headers: " + headers);
		HostSetUrlHeaderHTTP(url, headers);
	}
}


string PlayitemParse(const string &in path, dictionary &MetaData, array<dictionary> &QualityList)
{
	// Called after PlayitemCheck if it returns true
//HostPrintUTF8("PlayitemParse - " + path);
	
	uint startTime = HostGetTickCount();
	g_startTime = startTime;
	
	if (cfg.csl > 0) HostOpenConsole();
	
	string inUrl = _ReviseUrl(path);
	string outUrl;
	
	string httpHead = _GetHttpHeader(inUrl, 5);
	if (sch.findRegExp(httpHead, "(?i)HTTP/\\d\\.\\d 20\\d") >= 0)
	{
		string ext0 = _GetUrlExtension(inUrl);
		if (ext0 == "m3u8" || ext0 == "txt")
		{
			if (!_CheckM3u8Hls(inUrl)) return "";
		}
		
		string fileType = _GetFileType(httpHead);
		if (!fileType.empty())
		{
			if (cfg.getInt("TARGET", "direct_file_info") == 1)
			{
				_SetFileInfo(MetaData, inUrl, httpHead, (fileType != "audio"));
				if (cfg.csl > 0)
				{
					HostPrintUTF8("[yt-dlp] Got matadata for a direct media file. - " + ytd.qt(inUrl) + "\r\n\r\n");
				}
				outUrl = inUrl;
				return outUrl;
			}
			return "";
		}
		
		if (_IsUrlSite(inUrl, "shoutcast"))
		{
			outUrl = shoutpl.parse(inUrl, MetaData, QualityList, true);
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
					HostPrintUTF8("[yt-dlp] Parsed Shoutcast playlist. - " + ytd.qt(inUrl) + "\r\n\r\n");
				}
				if (cfg.getInt("TARGET", "radio_info") == 1)
				{
					_GetRadioInfo(MetaData, httpHead, outUrl);
				}
				return outUrl;
			}
		}
		
		if (cfg.getInt("TARGET", "radio_info") == 1)
		{
			if (_GetRadioInfo(MetaData, httpHead, inUrl))
			{
				if (cfg.csl > 0)
				{
					HostPrintUTF8("\r\nStation: " + string(MetaData["title"]) + "\r\n");
					HostPrintUTF8("[yt-dlp] Got metadata for a streaming radio. - " + ytd.qt(inUrl) + "\r\n\r\n");
				}
				outUrl = inUrl;
				return outUrl;
			}
		}
		else
		{
			if (_CheckRadioServer(httpHead))
			{
				if (cfg.csl > 0)
				{
					HostPrintUTF8("[yt-dlp] This URL is for a streaming radio. - " + ytd.qt(inUrl) + "\r\n\r\n");
				}
				outUrl = inUrl;
				return outUrl;
			}
		}
	}
	
	if (_CheckStartTime(startTime, path)) return "";
	
	// Execute yt-dlp
	array<string> entries = ytd.exec1(inUrl, 0, "");
	if (entries.length() == 0) return "";
	
	if (_CheckStartTime(startTime, path)) return "";
	
	string json = entries[0];
	JsonReader reader;
	JsonValue root;
	if (!reader.parse(json, root) || !root.isObject())
	{
		HostPrintUTF8("[yt-dlp] CRITICAL ERROR! JSON data corrupted.\r\n");
		ytd.criticalError(); return "";
	}
	
	JsonValue jVersion = root["_version"];
	if (!jVersion.isObject())
	{
		HostPrintUTF8("[yt-dlp] CRITICAL ERROR! No version info.\r\n");
		ytd.criticalError(); return "";
	}
	else
	{
		string version = _GetJsonValueString(jVersion, "version");
		if (version.empty())
		{
			HostPrintUTF8("[yt-dlp] CRITICAL ERROR! No version info.\r\n");
			ytd.criticalError(); return "";
		}
	}
	
	string extractor = _GetJsonValueString(root, "extractor_key");
	if (extractor.empty()) extractor = _GetJsonValueString(root, "extractor");
	if (extractor.empty())
	{
		HostPrintUTF8("[yt-dlp] CRITICAL ERROR! No extractor.\r\n");
		ytd.criticalError(); return "";
	}
	bool isGeneric = _isGeneric(extractor);
	
	string webUrl = _GetJsonValueString(root, "webpage_url");
	if (webUrl.empty())
	{
		HostPrintUTF8("[yt-dlp] CRITICAL ERROR! No webpage URL.\r\n");
		ytd.criticalError(); return "";
	}
	MetaData["webUrl"] = webUrl;
	
	bool isYoutube = _IsUrlSite(inUrl, "youtube");
	
	bool isLive = _GetJsonValueBool(root, "is_live");
	int concurrentViewCount = _GetJsonValueInt(root, "concurrent_view_count");
	if (concurrentViewCount > 0) isLive = true;
	if (!isLive)
	{
		string liveStatus = _GetJsonValueString(root, "live_status");
		if (liveStatus == "is_live") isLive = true;
	}
	if (isLive)
	{
		if (isYoutube)
		{
			if (cfg.getInt("YOUTUBE", "youtube_live") != 1)
			{
				if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] YouTube Live was passed through according to the [youtube_live] setting. - " + ytd.qt(inUrl) +"\r\n");
				return "";
			}
		}
		
		// support live chat
		if (cfg.getInt("TARGET", "live_chat") == 1)
		{
			string chatUrl = _GetChatUrl(inUrl);
			if (!chatUrl.empty())
			{
				MetaData["chatUrl"] = chatUrl;
			}
		}
	}
	
	string ext = _GetJsonValueString(root, "ext");
	if (!ext.empty()) MetaData["fileExt"] = ext;
	
	bool isAudioExt = _IsExtType(ext, 0x100);
	
	string thumb = _GetJsonValueString(root, "thumbnail");
	if (thumb.Right(4) == ".svg")
	{
		// .svg -> .png (PotPlayer does not support svg)
		thumb = thumb.Left(thumb.length() - 4) + ".png";
	}
	
	if (thumb.empty())
	{
		if (isLive && sch.findI(extractor, "TwitchVod") == 0)
		{
			// No thumbnail if using the --live-from-start option
			array<string> _entries = ytd.exec2({inUrl}, -1);
			if (_entries.length() == 1)
			{
				thumb = _GetDataValueString(_entries[0], "thumbnail");
				// Not support for "thumbnails" of playlist data)
			}
		}
	}
	
	int playlistIdx = _GetJsonValueInt(root, "playlist_index");
	if (playlistIdx > 0 && inUrl != webUrl)
	{
		// playlist url
		if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] This URL is for a playlist.\r\n");
		
		MetaData["thumbnail"] = thumb;
		outUrl = _PlaylistParseNotExtract(inUrl, MetaData);
		
		if (_CheckStartTime(startTime, path)) return "";
		
		if (_WebsitePlaylistMode(inUrl) > 0)
		{
			_PotPlayerAddList(inUrl, 0);
		}
		
		return outUrl;
	}
	
	outUrl = _GetJsonValueString(root, "url");
	if (!outUrl.empty())
	{
		string protocol = _GetJsonValueString(root, "protocol");
		if (!protocol.empty() && _CheckProtocol(protocol))
		{
			outUrl = "";
		}
	}
	
	int needPlaybackCookie = 0;
	
	if (!outUrl.empty())
	{
		_SetHeaders(outUrl, root, needPlaybackCookie);
	}
	
	string title = _GetJsonValueString(root, "title");
	if (!title.empty())
	{
		if (cfg.getInt("FORMAT", "more_detailed_title") == 1)
		{
			string alt_title = _GetJsonValueString(root, "alt_title");
			if (!alt_title.empty() && alt_title.find(title) >= 0)
			{
				title = alt_title;
			}
		}
		title = _ReviseWebString(title);
	}
	
	string duration = _GetJsonValueString(root, "duration_string");
	float dcmDuration = _GetJsonValueFloat(root, "duration");	// treat as a decimal
	if (duration.empty())
	{
		if (dcmDuration > 0)
		{
			duration = "0:" + int(dcmDuration);
			// Convert to format "hh:mm:ss" with adding "0:" to the top
		}
	}
	if (!duration.empty()) MetaData["duration"] = duration;
	
	string id = _GetJsonValueString(root, "id");
	if (!id.empty()) MetaData["vid"] = id;
	
	string author;
	string author2;	// substantial author
	author = _GetJsonValueString(root, "channel");
	if (!author.empty()) author2 = author;
	else
	{
		author = _GetJsonValueString(root, "uploader");
		if (!author.empty()) author2 = author;
		else
		{
			author = _GetJsonValueString(root, "uploader_id");
			if (author.Left(1) == "@")	// youtube
			{
				author = author.substr(1);
				author.replace("_", " ");
			}
			if (!author.empty()) author2 = author;
			else
			{
				author = _GetJsonValueString(root, "atrist");
				if (!author.empty()) author2 = author;
				else
				{
					author = _GetJsonValueString(root, "creator");
					if (!author.empty()) author2 = author;
					else
					{
						if (isGeneric)
						{
							string urlDomain = _GetJsonValueString(root, "webpage_url_domain");
							author = _GetUrlDomain(urlDomain);
						}
					}
				}
			}
		}
	}
	if (!author.empty()) author = _ReviseWebString(author);
	
	string _author = author;
	if (isGeneric)
	{
		if (sch.findI(title, "Shoutcast Server") == 0)
		{
			_author += (!author.empty() ? " " : "") + "@ShoutcastCh";
		}
	}
	else
	{
		_author += (!author.empty() ? " " : "") + "@" + extractor;
	}
	if (!_author.empty()) MetaData["author"] = _author;
	
	string date = _GetJsonValueString(root, "upload_date");
	date = _ReviseDate(date);
	if (!date.empty()) MetaData["date"] = date;
	
	string desc = _GetJsonValueString(root, "description");
	desc = _ReviseWebString(desc);
	
	string baseName = _GetJsonValueString(root, "webpage_url_basename");
	string ext2 = HostGetExtension(baseName);	// include the top dot
	
	if (_CheckStartTime(startTime, path)) return "";
	
	string title2;	// substantial title
	{
		if (!title.empty() && baseName == title + ext2) {}
			// MetaData["title"] is empty if yt-dlp cannot get a substantial title,
			// to prevent potplayer from overwriting the edited title in the playlist panel.
		else if (sch.findI(title, "Shoutcast Server") == 0) {}
		else
		{
			title2 = title;
		}
		if (_TitleAuthorSites(extractor))
		{
			if (title2.find(author + " - ") == 0)
			{
				title2 = title2.substr(author.length() + 3);
			}
		}
		if (sch.findI(extractor, "facebook") >= 0)	// facebook
		{
			// Remove the count of playback/reactions/share in the title top
			int pos = title2.findFirst(" | ");
			if (pos >= 0) title2 = title2.substr(pos + 3);
			
			// Remove the uploader's name
			pos = title2.findLast(" | ");
			if (pos >= 0) title2 = title2.Left(pos);
		}
		if (!desc.empty() && sch.isCutOffString(title2, desc))
		{
			title2 = "";
		}
		if (title2.empty() || title2 == author || title2 == "Video by " + author)
		{
			if (!desc.empty())
			{
				title2 = desc;
			}
			else if (!isGeneric)
			{
				title2 = author + " (" + extractor + ") " + date;
			}
		}
		if (title2.find(author) == 0)
		{
			string _date = sch.getRegExp(title2.substr(author.length()), "(?i)^ \\(live\\) (\\d{4}\\-\\d{2}\\-\\d{2}.*)$");
			if (!_date.empty())
			{
				if (!desc.empty())
				{
					title2 = desc;
				}
				else if (!isGeneric)
				{
					title2 = author + " (" + extractor + ") " + _date;
				}
			}
		}
		title2 = _CutOffString(title2);
		if (sch.isSameDesc(title2, desc))
		{
			desc = "";	// Delete duplicate desc data
		}
		if (isLive && !author2.empty())
		{
			string livePrefix = cfg.getStr("FORMAT", "live_prefix");
			title2 = livePrefix + title2;
		}
		if (!title2.empty())
		{
			MetaData["title"] = title2;
		}
		if (!desc.empty())
		{
			MetaData["content"] = desc;
		}
	}
	if (cfg.csl > 0)
	{
		HostPrintUTF8("\r\n");
		HostPrintUTF8("Title: " + title2 + "\r\n");
		//HostPrintUTF8("\r\nDescription:\r\n" + desc + "\r\n");
		HostPrintUTF8("\r\n");
	}
	
	int viewCount = 0;
	if (concurrentViewCount > 0)
	{
		viewCount = concurrentViewCount;
	}
	else
	{
		viewCount = _GetJsonValueInt(root, "view_count");
	}
	if (viewCount > 0) MetaData["viewCount"] = formatInt(viewCount);
	
	int likeCount = _GetJsonValueInt(root, "like_count");
	if (likeCount > 0) MetaData["likeCount"] = formatInt(likeCount);
	
	//MetaData["fileExt"] = "mp4";
	
	JsonValue jFormats = root["formats"];
	if (!jFormats.isArray() || jFormats.size() == 0)
	{
		// Do not treat it as an error.
		// For getting uploader(website) or thumbnail or upload date.
		if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] No formats data...\r\n");
	}
	
	if (_CheckStartTime(startTime, path)) return "";
	
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
		
		string protocol = _GetJsonValueString(jFormat, "protocol");
		if (_CheckProtocol(protocol))
		{
			continue;
		}
		
		string fmtUrl = _GetJsonValueString(jFormat, "url");
//HostPrintUTF8("fmtUrl: " + fmtUrl);
		if (fmtUrl.empty()) continue;
		
		string fmtExt = _GetJsonValueString(jFormat, "ext");
		string vExt = _GetJsonValueString(jFormat, "video_ext");
		string aExt = _GetJsonValueString(jFormat, "audio_ext");
		if (fmtExt.empty() || vExt.empty() || aExt.empty()) continue;
		
		string vcodec = _GetJsonValueString(jFormat, "vcodec");
		vcodec = sch.omitDecimal(vcodec, ".", 1);
		
		string acodec = _GetJsonValueString(jFormat, "acodec");
		acodec = sch.omitDecimal(acodec, ".", 1);
		
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
		
		string audioCode = _GetJsonValueString(jFormat, "language");
		if (audioCode == "und") audioCode = "";	// undetermined
		
		string audioName;	// audio language name in base_lang on YouTube
		bool audioIsDefault = false;
		
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
		
		string note = _GetJsonValueString(jFormat, "format_note");
		if (!note.empty())
		{
			if (va == "a" || va == "va")
			{
				if (!audioCode.empty())
				{
					audioIsDefault = (note.find("(default)") >= 0);
					if (isYoutube && multiLang)
					{
						if (_HideDubbed(audioCode, va, audioIsDefault))
						{
							continue;
						}
						audioName = _SupposeLangName(note);
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
		
		int height = _GetJsonValueInt(jFormat, "height");
		int width = _GetJsonValueInt(jFormat, "width");
		int longSide = (width < height ? height : width);
		float vbr = _GetJsonValueFloat(jFormat, "vbr");
		float tbr = _GetJsonValueFloat(jFormat, "tbr");
		float abr = _GetJsonValueFloat(jFormat, "abr");
		
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
			string bitrate;
			if (tbr > 0) bitrate = HostFormatBitrate(int(tbr * 1000));
			else if (vbr > 0 && abr > 0) bitrate = HostFormatBitrate(int((abr + vbr) * 1000));
			else if (vbr > 0) bitrate = HostFormatBitrate(int(vbr * 1000));
			else if (abr > 0) bitrate = HostFormatBitrate(int(abr * 1000));
			
			float fps = _GetJsonValueFloat(jFormat, "fps");
			
			string dynamicRange = _GetJsonValueString(jFormat, "dynamic_range");
			if (dynamicRange.empty() && va != "a") dynamicRange = "SDR";
			
			string resolution = "";
			if (width > 0 && height > 0)
			{
				resolution = formatInt(width) + "×" + formatInt(height);
			}
			else
			{
				resolution = _GetJsonValueString(jFormat, "resolution");
			}
			
			int itag = 0;
			if (isYoutube)
			{
				itag = parseInt(_GetJsonValueString(jFormat, "format_id"));
//HostPrintUTF8("itag: " + itag);
			}
			
			string quality;
			string format;
			
			if (va == "a")
			{
				float bps = tbr > 0 ? tbr : abr;
				if (bps <= 0) bps = 128;
				quality = HostFormatBitrate(int(bps * 1000));
				
				format += fmtExt;
				if (!acodec.empty() && acodec != "none")
				{
					format += ", " + acodec;
				}
				
				if (itag <= 0 || HostExistITag(itag))
				{
					itag = HostGetITag(0, int(bps), fmtExt == "mp4", fmtExt == "webm" || fmtExt == "m3u8");
					if (itag <= 0) itag = HostGetITag(0, int(bps), true, true);
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
					if (itag <= 0) itag = HostGetITag(height, 0, true, true);
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
					if (itag <= 0) itag = HostGetITag(height, int(abr), true, true);
				}
			}
			if (quality.empty())
			{
				string origFormat = _GetJsonValueString(jFormat, "format");
				if (!origFormat.empty())
				{
					quality = origFormat;
				}
				else
				{
					quality = _GetJsonValueString(jFormat, "format_id");
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
			
			if (va == "v" || va == "va")
			{
				//if (is360) dic["is360"] = true;
				//if (type3D > 0) dic["type3D"] = type3D;
			}
			
			while (HostExistITag(itag)) itag++;
			HostSetITag(itag);
			dic["itag"] = itag;
			
			dic["va"] = va;
			if (!dynamicRange.empty())
			{
				dic["dynamicRange"] = dynamicRange;
				if (sch.findI(dynamicRange, "SDR") < 0)
				{
					dic["isHDR"] = true;
				}
			}
			if (!audioCode.empty()) dic["audioCode"] = audioCode;
			if (!audioName.empty())
			{
				dic["audioName"] = audioName;
			}
			dic["audioIsDefault"] = audioIsDefault;
			
			if (cfg.getInt("FORMAT", "remove_duplicate_quality") == 1)
			{
				if (_IsQualityDuplicate(dic, QualityList))
				{
					continue;
				}
			}
			
			_SetHeaders(fmtUrl, jFormat, needPlaybackCookie);
			
			QualityList.insertLast(dic);
		}
		
		if (va == "v")	// prioritize dash over hls
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
		else if (va == "va")
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
		if (!vaOutUrl.empty()) outUrl = vaOutUrl;
		else if (!vOutUrl.empty()) outUrl = vOutUrl;
		else if (!aOutUrl.empty()) outUrl = aOutUrl;
	}
	
	if (thumb.empty())
	{
		if (!isAudioExt)
		{
			thumb = outUrl;
		}
	}
	if (!thumb.empty()) MetaData["thumbnail"] = thumb;
	
	//if (is360) MetaData["is360"] = 1;
	//if (type3D > 0) MetaData["type3D"] = type3D;
	
	if (@QualityList !is null && QualityList.length() > 0)
	{
		if (isYoutube && multiLang)
		{
			_FillAudioName(QualityList);
		}
		if (is360)
		{
			//_FillVR(QualityList, type3D);
		}
		
		if (cfg.csl > 1)
		{
			for (uint i = 0; i < QualityList.length(); i++)
			{
				string va = string(QualityList[i]["va"]);
				string audioCode = string(QualityList[i]["audioCode"]);
				string audioName = string(QualityList[i]["audioName"]);
				string quality = string(QualityList[i]["quality"]);
				string format = string(QualityList[i]["format"]);
				string link = string(QualityList[i]["url"]);
				int itag = int(QualityList[i]["itag"]);
				
				string fmtMsg = "Format: ";
				fmtMsg += (va == "v") ? "[video] " : (va == "a") ? "[audio] " : "[video/audio] ";
				fmtMsg += !audioName.empty() ? (audioName + ", ") : !audioCode.empty() ? (audioCode + ", ") : "";
				fmtMsg += quality + ", " + format + " <" + itag + ">\r\n";
				fmtMsg += link + "\r\n";
				HostPrintUTF8(fmtMsg);
			}
			HostPrintUTF8("\r\n");
		}
	}
	else if (!outUrl.empty())
	{
		HostPrintUTF8("URL: " + outUrl + "\r\n\r\n");
	}
	
	if (_CheckStartTime(startTime, path)) return "";
	
	array<dictionary> dicsSub;
	JsonValue jSubtitles = root["requested_subtitles"];
	if (jSubtitles.isObject())
	{
		array<string> subs = jSubtitles.getKeys();
		for (uint i = 0; i < subs.length(); i++)
		{
			string langCode = subs[i];
			if (sch.findRegExp(langCode, "chat|danmaku|und") >= 0) continue;
			JsonValue jSub = jSubtitles[langCode];
			if (jSub.isObject())
			{
				string subUrl = _GetJsonValueString(jSub, "url");
				if (!subUrl.empty())
				{
					// .vtt.m3u8 -> .vtt
					int pos = sch.findRegExp(subUrl, "(?i)\\.vtt(\\.m3u8)(?:\\?.*)?$");
					if (pos > 0) subUrl.erase(pos, 5);
				}
				string subData = _GetJsonValueString(jSub, "data");
				
				if (!subUrl.empty() || !subData.empty())
				{
					dictionary dic;
					dic["langCode"] = langCode;
					if (!subUrl.empty()) dic["url"] = subUrl;
					if (!subData.empty()) dic["data"] = subData;
					string langName = _GetJsonValueString(jSub, "name");
					if (!langName.empty()) dic["name"] = langName;
					if (sch.findRegExp(langCode, "(?i)\\bAuto") >= 0)
					{
						// Auto-generated
						dic["kind"] = "asr";
					}
					dicsSub.insertLast(dic);
				}
			}
		}
	}
	uint mainSubCnt = dicsSub.length();
	jSubtitles = root["automatic_captions"];
	if (jSubtitles.isObject())
	{
		array<string> subs = jSubtitles.getKeys();
		for (uint i = 0; i < subs.length(); i++)
		{
			string langCode = subs[i];
			if (_SelectAutoSub(langCode, dicsSub))
			{
				JsonValue jSubs = jSubtitles[langCode];
				if (jSubs.isArray())
				{
					for (int j = jSubs.size() - 1; j >= 0; j--)
					{
						JsonValue jSsub = jSubs[j];
						if (jSsub.isObject())
						{
							string subExt = _GetJsonValueString(jSsub, "ext");
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
								if (sch.findI(subExt, targetSubExt) >= 0)
								{
									string subUrl = _GetJsonValueString(jSsub, "url");
									if (!subUrl.empty())
									{
										dictionary dic;
										dic["kind"] = "asr";
										dic["langCode"] = langCode;
										dic["url"] = subUrl;
										string langName = _GetJsonValueString(jSsub, "name");
										if (!langName.empty())
										{
											langName += " (auto-generated)";
											dic["name"] = langName;
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
	if (dicsSub.length() > 0)
	{
		MetaData["subtitle"] = dicsSub;
		
		if (cfg.csl > 1)
		{
			for (uint i = 0; i < dicsSub.length(); i++)
			{
				string key = (i < mainSubCnt) ? "Sub" : "Auto-Sub";
				string langCode = string(dicsSub[i]["langCode"]);
				string langName = string(dicsSub[i]["name"]);
				string subUrl = string(dicsSub[i]["url"]);
				HostPrintUTF8(key + ": [" + langCode + "] " + langName + "\r\n" + subUrl + "\r\n");
			}
			HostPrintUTF8("\r\n");
		}
	}
	
	array<dictionary> dicsChapter;
	JsonValue jChapters = root["chapters"];
	if (jChapters.isArray())
	{
		for(int i = 0; i < jChapters.size(); i++)
		{
			JsonValue jChapter = jChapters[i];
			if (jChapter.isObject())
			{
				string chptTitle = _GetJsonValueString(jChapter, "title");
				if (!chptTitle.empty())
				{
					int msTime = int(_GetJsonValueFloat(jChapter, "start_time") * 1000);	// millisecond
					if (msTime >= 0)
					{
						dictionary dic;
						dic["title"] = chptTitle;
						if (isLive)
						{
							// For Twitch with --live-from-start
							// Generally PotPlayer cannot reflect chapter positions on live stream.
							if (dcmDuration > 0)
							{
								int msDuration = int(dcmDuration * 1000);
								msTime -= msDuration;
								// Negative number means the past
							}
							else
							{
								msTime = 0;
							}
						}
						dic["time"] = formatInt(msTime);
						dicsChapter.insertLast(dic);
						if (cfg.csl > 1)
						{
							HostPrintUTF8("Chapter: [" + sch.formatTime(msTime) + "] " + chptTitle);
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
			if (dicsChapter.length() == 0)
			{
				addFirst = 1;
			}
			else if (parseInt(string(dicsChapter[0]["time"])) != 0)
			{
				addFirst = 1;
			}
			else if (string(dicsChapter[0]["title"]) == "<Untitled Chapter 1>")
			{
				dicsChapter[0]["title"] = untitledChptName;
				addFirst = 2;
			}
			if (addFirst == 1)
			{
				dictionary dic;
				dic["title"] = untitledChptName;
				dic["time"] = "0";
				dicsChapter.insertAt(0, dic);
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
						string category = _GetJsonValueString(jSBChapter, "category");
						if (category == sb.CATEGORIES[i])
						{
							string chptTitle = _GetJsonValueString(jSBChapter, "title");
							int msTime1 = int(_GetJsonValueFloat(jSBChapter, "start_time") * 1000);	// millisecond
							int msTime2 = int(_GetJsonValueFloat(jSBChapter, "end_time") * 1000);	// millisecond
							if (!chptTitle.empty() && msTime1 >= 0 && msTime2 > msTime1)
							{
								string chptTitle1 = sb.reviseChapter(chptTitle);
								string chptTitle2;
								sb.removeChptRange(dicsChapter, msTime1, msTime2, chptTitle2, cfg.csl > 1);
								if (chptTitle2.empty()) chptTitle2 = untitledChptName;
								
								dictionary dic1;
								dic1["title"] = chptTitle1;
								dic1["time"] = formatInt(msTime1);
								dicsChapter.insertLast(dic1);
								if (cfg.csl > 1)
								{
									HostPrintUTF8("SB Chapter Start: [" + sch.formatTime(msTime1) + "] " + chptTitle1);
								}
								
								int msDuration = int(dcmDuration * 1000);
								if (msDuration <= 0 || msDuration > msTime2 + sb.THRSH_TIME)
								{
									dictionary dic2;
									dic2["title"] = chptTitle2;
									dic2["time"] = formatInt(msTime2);
									dicsChapter.insertLast(dic2);
									if (cfg.csl > 1)
									{
										HostPrintUTF8("SB Chapter End:   [" + sch.formatTime(msTime2) + "] " + chptTitle2);
									}
								}
							}
						}
					}
				}
			}
		}
	}
	if (dicsChapter.length() > 0)
	{
		MetaData["chapter"] = dicsChapter;
		if (cfg.csl > 1) HostPrintUTF8("\r\n");
	}
	
	// Keep the hash of yt-dlp.exe, which works without issues.
	if (!ytd.tmpHash.empty() && ytd.tmpHash != cfg.getStr("MAINTENANCE", "ytdlp_hash"))
	{
		cfg.setStr("MAINTENANCE", "ytdlp_hash", ytd.tmpHash);
	}
	ytd.backupExe();
	
	if (_CheckStartTime(startTime, path)) return "";
	
	if (cfg.csl > 0)
	{
		HostPrintUTF8("[yt-dlp] Parsing complete (" + extractor + "). - " + ytd.qt(inUrl) +"\r\n");
		
		if (needPlaybackCookie > 0)
		{
			string msg = "[yt-dlp] PotPlayer may not play this stream. The cookies are required during playback.";
			msg += " - " + ytd.qt(inUrl) + "\r\n";
			HostPrintUTF8(msg);
		}
	}
	
	return outUrl;
}


