﻿/*************************************************************
  Parse Streaming with yt-dlp
**************************************************************
  Extension script for PotPlayer 250226 or later versions
  Placed in \PotPlayer\Extension\Media\PlayParse\
*************************************************************/

string SCRIPT_VERSION = "251025";


string YTDLP_EXE = "Module\\yt-dlp.exe";
	// yt-dlp executable file; relative path to HostGetExecuteFolder(); (required)

string SCRIPT_CONFIG_DEFAULT = "yt-dlp_default.ini";
	// default configuration file; placed in HostGetScriptFolder(); (required)

string SCRIPT_CONFIG_CUSTOM = "Extension\\Media\\PlayParse\\yt-dlp.ini";
	// configuration file; relative path to HostGetConfigFolder()
	// created automatically with this script

string RADIO_IMAGE_1 = "yt-dlp_radio1.jpg";
string RADIO_IMAGE_2 = "yt-dlp_radio2.jpg";
	// radio image files; placed in HostGetScriptFolder()


class FileConfig
{
	string codeDef;	// encoding of default config file
	
	bool showDialog = false;
	bool errorDefault = false;
	bool errorSave = false;
	
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
		if (fp <= 0)
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
							"This default config file is for a DIFFERENT VERSION of the script.\r\n"
							"Please use the one for [" + curVer + "].\r\n\r\n";
						}
					}
				}
			}
		}
		
		if (msg.empty())
		{
			errorDefault = false;
		}
		else
		{
			errorDefault = true;
			str = "";
			if (showDialog)
			{
				showDialog = false;
				msg += HostGetScriptFolder() + "\r\n" + SCRIPT_CONFIG_DEFAULT;
				HostMessageBox(msg, "[yt-dlp] ERROR: Default config file", 0, 0);
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
					if (HostFileWrite(fp, str) == int(str.size()))
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
			errorSave = false;
		}
		else
		{
			errorSave = true;
			if (showDialog)
			{
				showDialog = false;
				string msg =
				"The script cannot create or save the config file.\r\n"
				"Please ensure this file is writable.\r\n\r\n"
				+ HostGetConfigFolder() + SCRIPT_CONFIG_CUSTOM;
				HostMessageBox(msg, "[yt-dlp] ERROR: File save", 0, 0);
			}
		}
		return writeState;
	}
	
};

FileConfig fc;

//----------------------- END of class FileConfig -------------------------


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
};

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
	
	string _escapeQuote(string str)
	{
		// Do not use Trim("\"")
		if (str.Left(1) == "\"" && str.Right(1) == "\"")
		{
			str = str.substr(1, str.size() - 2);
		}
		int pos = 0;
		int pos0;
		do {
			pos0 = pos;
			pos = str.find("\"", pos);
			if (pos >= 0)
			{
				str.insert(pos, "\\");
				pos += 2;
			}
		} while (pos > pos0);
		return str;
	}
	
	int _findBlankLine(string str, int pos)
	{
		if (pos < 0) pos = str.size();
		pos = str.findLastNotOf("\r\n", pos);
		if (pos < 0) pos = 0;
		int pos0;
		do {
			pos0 = pos;
			pos = str.find("\n", pos);
			if (pos >= 0)
			{
				for (pos += 1; uint(pos) < str.size(); pos++)
				{
					string c = str.substr(pos, 1);
					if (c == "\n") return pos + 1;
					if (c != "\r") break;
				}
			}
		} while (pos > pos0);
		return str.size();
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
		if (str.empty() || pos < 0 || uint(pos) >= str.size()) {pos = -1; return "";}
		
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
		if (str.empty() || pos < 0 || uint(pos) >= str.size()) {pos = -1; return "";}
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
				keyArea.erase(pos2, line.size());
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
				pos += keyArea.size();
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
				pos += sectArea.size();
			}
			else
			{
				break;
			}
		} while (pos > pos0);
		
		if (sectionNamesDef.size() == 0)
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
					str.erase(keyTop, s1.size());
					str.insert(keyTop, kd.key + "=");
					valueTop = keyTop + kd.key.size() + 1;
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
						kd.valueTop = keyTop + kd.key.size() + 1;
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
		for (uint i = 0; i < keys.size(); i++)
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
		
		for (uint i = 0; i < keys.size(); i++)
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
						uint _pos = (uint(idx) < tops.size()) ? tops[idx] : sectArea.size();
						int blnk = _findBlankLine(sectArea, kd.areaTop);
						if (_pos > uint(blnk)) _pos = blnk;
						keyArea = sectArea.substr(kd.areaTop, _pos - kd.areaTop);
					}
					{
						// Reflect the default description.
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
					// Add missing keys.
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
		if (sections.size() == 1 && sections[0] == "")
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
							section = sections[idx];	// Correct case difference.
							sections.removeAt(idx);
							sectionNamesCst.insertLast(section);
							__loadCst(sectArea, section);
						}
					}
					pos += sectArea.size();
				}
			} while (pos > pos0);
			
			// Add the missing section
			for (uint i = 0; i < sections.size(); i++)
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
		if (sections.size() == 0 || kds.size() == 0) return "";
		
		string str = "";
		for (uint i = 0; i < sections.size(); i++)
		{
			string section = sections[i];
			if (!section.empty())
			{
				str += "[" + section + "]\r\n\r\n";
			}
			array<string> keys;
			if (keyNames.get(section, keys))
			{
				for (uint j = 0; j < keys.size(); j++)
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
		if (sections.size() == 0 || kds.size() == 0) return "";
		
		string str = "";
		if (!section.empty())
		{
			str += "[" + section + "]\r\n\r\n";
		}
		array<string> keys;
		if (keyNames.get(section, keys))
		{
			for (uint j = 0; j < keys.size(); j++)
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
		if (sections.size() == 0 || kds.size() == 0) return "";
		
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
			if (criticalError != 0 || ytd.error != 0)
			{
				deleteKey("MAINTENANCE", "update_ytdlp", false);
			}
		}
		
		string str2 = _getCfgStrCst();
		
		fc.closeFileCst(fp, str2 != str0, str2);
		
		{
			// specific properties of each script
			csl = getInt("MAINTENANCE", "console_out");
			if (csl < 0 || csl > 3) csl = 0;
			baseLang = getStr("YOUTUBE", "base_lang");
			if (baseLang.empty()) baseLang = HostIso639LangName();
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
		return _escapeQuote(_getValue(section, key, useDef));
	}
	
	string getStr(string key, int useDef = 0)
	{
		return _escapeQuote(_getValue("", key, useDef));
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
						kd.areaStr.erase(kd.valueTop, prevValue.size());
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
						kd.valueTop = kd.keyTop + key.size() + 1;
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
		return _escapeQuote(prevValue);
	}
	
	string setStr(string key, string sValue, bool save = true)
	{
		string prevValue = _setValue("", key, sValue, save);
		return _escapeQuote(prevValue);
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
	
};

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
		for (uint i = 0; i < arr.size(); i++)
		{
			if (arr[i].MakeLower() == search.MakeLower()) return i;
		}
		return -1;
	}
	
	string escapeReg(string str)
	{
		array<string> esc = {"\\", "|", ".", "+", "-", "*", "/", "^", "$", "(", ")", "[", "]", "{", "}"};
		for (uint i = 0; i < esc.size(); i++)
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
		for (uint pos = 0; pos < reg.size(); pos++)
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
	
	int regExpParse(string str, string reg, array<dictionary> &inout match, int fromPos)
	{
		// Modify HostRegExpParse
		if (str.empty() || reg.empty() || match is null) return -1;
		if (fromPos < 0 || uint(fromPos) >= str.size()) return -1;
		string origStr = str;
		bool caseInsens = false;
		if (reg.Left(4) == "(?i)")
		{
			// Case-insensitive (not available to HostRegExpParse)
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
			for (uint i = 0; i < _match.size(); i++)
			{
				string s1 = string(_match[i]["first"]);
				string s2 = string(_match[i]["second"]);
				int pos = _str.size() - s2.size() - s1.size();
				pos = fromPos + pos;
				{
					dictionary dic;
					if (!caseInsens)
					{
						dic["str"] = s1;
					}
					else
					{
						dic["str"] = origStr.substr(pos, s1.size());
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
			if (match.size() > 1)
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
			if (match.size() > 1)
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
			if (match.size() > 1)
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
		if (pos < 0 || pos > int(str.size())) pos = str.size();
		if (pos == 0) return 0;
		pos = str.findLastOf("\n", pos - 1);
		if (pos < 0) return 0;
		return pos + 1;
	}
	
	int findEol(string str, int pos)
	{
		// Does not include EOL characters at the end
		if (pos < 0 || pos >= int(str.size())) return int(str.size());
		pos = str.find("\n", pos);
		if (pos < 0) return int(str.size());
		if (pos == 0) return 0;
		if (str.substr(pos - 1, 1) == "\r") pos -= 1;
		return pos;
	}
	
	int findNextLineTop(string str, int pos)
	{
		if (pos < 0 || pos >= int(str.size())) return -1;
		pos = str.find("\n", pos);
		if (pos < 0) return -1;
		return pos + 1;
	}
	
	int findPrevLineTop(string str, int pos)
	{
		if (pos < 0 || pos > int(str.size())) pos = str.size();
		if (pos == 0) return -1;
		pos = str.findLast("\n", pos - 1);
		if (pos < 0) return -1;
		pos = findLineTop(str, pos);
		return pos;
	}
	
	void eraseLine(string &inout str, int pos)
	{
		if (pos >= 0 && pos <= int(str.size()))
		{
			int pos1 = findLineTop(str, pos);
			int pos2 = findNextLineTop(str, pos);
			if (pos2 < 0) pos2 = str.size();
			str.erase(pos1, pos2 - pos1);
		}
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
	
	string cutoffDesc(string desc, uint len)
	{
		if (len == 0) return desc;
		string str;
		if (desc.size() > len)
		{
			int pos = _findCharaTop(desc, len);
			str = desc.Left(pos);
			str += "...";
		}
		else
		{
			str = desc;
		}
		//str.replace("\n", " ");
		return str;
	}
	
	bool isCutoffDesc(string str, string desc)
	{
		while (str.Right(1) == ".") str.erase(str.size() - 1);
		str.replace("\n", " ");
		desc.replace("\n", " ");
		return (desc.find(str) == 0);
	}
	
	string omitDecimal(string str, string dot, int allowedDigit = -1)
	{
		int pos = str.find(dot);
		if (pos < 0) return str;
		string decimal = str.substr(pos + dot.size());
		if (int(decimal.size()) > allowedDigit)
		{
			str = str.Left(pos);
		}
		return str;
	}
	
	string decodeNumericCharRefs(const string input)
	{
		// decode numeric character references in UTF8
		// &#84;&#252;&#114;&#107;&#231;&#101; -> Türkçe
		// &#28450;&#23383; -> 漢字
		
		string output = "";
		uint i = 0;
		
		while (i < input.length())
		{
			if (i < input.length() - 2 && input[i] == charToCode("&") && input[i + 1] == charToCode("#"))
			{
				uint start = i;
				i += 2;
				
				bool isHex = false;
				if (i < input.length() && (input[i] == charToCode("x") || input[i] == charToCode("X")))
				{
					isHex = true;
					i++;
				}
				
				int charCode = 0;
				uint numStart = i;
				while (i < input.length() && input[i] != charToCode(";")) i++;
				if (i < input.length() && input[i] == charToCode(";"))
				{
					string numStr = input.substr(numStart, i - numStart);
					if (numStr.length() > 0)
					{
						if (isHex)
						{
							charCode = parseHex(numStr);
						}
						else
						{
							charCode = parseInt(numStr);
						}
						if (charCode > 0 && charCode <= 0x10FFFF)
						{
							output += charCodeToString(charCode);
							i++; // skip semicolon
							continue;
						}
					}
				}
				output += input.substr(start, i - start + 1);
				i++;
			}
			else
			{
				// ordinary character
				output += input.substr(i, 1);
				i++;
			}
		}
		return output;
	}
	
	uint charToCode(string chStr)
	{
		// Convert only a single byte at the top.
		if (chStr.size() == 1) return chStr[0];
		return 0;
	}
	
	string charCodeToString(int code)
	{
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
		else
		{
			// 4 bite code: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
			string output = "    ";
			output[0] = 0xF0 | (code >> 18);
			output[1] = 0x80 | ((code >> 12) & 0x3F);
			output[2] = 0x80 | ((code >> 6) & 0x3F);
			output[3] = 0x80 | (code & 0x3F);
			return output;
		}
	}
	
	int parseHex(const string hex)
	{
		int output = 0;
		for (uint i = 0; i < hex.length(); i++)
		{
			int digit = 0;
			uint8 ch = hex[i];
			
			if (ch >= charToCode("0") && ch <= charToCode("9"))
				digit = ch - charToCode("0");
			else if (ch >= charToCode("a") && ch <= charToCode("f"))
				digit = ch - charToCode("a") + 10;
			else if (ch >= charToCode("A") && ch <= charToCode("F"))
				digit = ch - charToCode("A") + 10;
			else
				return -1; // invalid
			
			output = output * 16 + digit;
		}
		return output;
	}
	
}

SCH sch;

//----------------------- END of class SCH -------------------------



class SHOUTPL
{
	
	string _removeNumber(string title)
	{
		string hidden = HostRegExpParse(title, "^(\\(#\\d[^)]+\\) ?)");
		if (!hidden.empty()) title = title.substr(hidden.size());
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
		uint itag = 0;
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
			
			if (@QualityList !is null)
			{
				dictionary dic;
				if (outUrl.empty()) outUrl = fmtUrl;
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
			pos += s0.size();
			string title = string(match[1]["str"]);
			{
				title = _removeNumber(title);
				if (i == 0) getTitle = title;
				else if (title != getTitle) break;
			}
			if (@QualityList !is null)
			{
				dictionary dic;
				string fmtUrl = string(match[2]["str"]);
				if (outUrl.empty()) outUrl = fmtUrl;
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
			pos += s0.size();
			string track = string(match[1]["str"]);
			string title = HostRegExpParse(track, "<title>(.+?)</title>");
			{
				title = _removeNumber(title);
				if (i == 0) getTitle = title;
				else if (title != getTitle) break;
			}
			if (@QualityList !is null)
			{
				dictionary dic;
				string fmtUrl = HostRegExpParse(track, "<location>(.+?)</location>");
				if (outUrl.empty()) outUrl = fmtUrl;
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
					title = _ReviseDesc(title);
					title = _CutoffDesc(title);
					MetaData["title"] = title;
						// station name; replaced to current music titles after playback starts
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
			for (uint i = 0; i < dicsMeta.size(); i++)
			{
				dictionary dic;
				string etrUrl = string(dicsMeta[i]["url"]);
				dic["url"] = etrUrl;
				dic["title"] = etrTitle;
				dic["author"] = etrAuthor;
				dic["thumbnail"] = etrThumb;
				dicsEntry.insertLast(dic);
			}
			return dicsMeta.size();
		}
		return 0;
	}
	
}

SHOUTPL shoutpl;

//----------------------- END of class SHOUTPL -------------------------



class YTDLP
{
	string fileExe = HostGetExecuteFolder() + YTDLP_EXE;
	string version = "";
	array<string> errors = {"(OK)", "(NOT FOUND)", "(LOOKS_DUMMY)", "(CRITICAL ERROR!)"};
	int error = 0;
	string SCHEME = "dl//";
	
	string qt(string str)
	{
		// Enclose in double quotes
		if (str.Right(1) == "\\")
		{
			// When enclosed as \"...\", escape the trailing back-slash character.
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
		if (!HostFileExist(fileExe))
		{
			error = 1; return;
		}
		
		FileVersion verInfo;
		if (!verInfo.Open(fileExe))
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
			// The copyright property in verInfo was removed from yt-dlp 250907.
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
	
	void _checkFileHash()
	{
		if (error > 0) return;
		
		if (!fc.errorDefault && !fc.errorSave)
		{
			uintptr fp = HostFileOpen(fileExe);
			string data = HostFileRead(fp, HostFileLength(fp));
			HostFileClose(fp);
			string hash = HostHashSHA256(data);
			if (hash.empty())
			{
				error = 2;
			}
			else
			{
				string hash0 = cfg.getStr("MAINTENANCE", "ytdlp_hash");
				if (hash0.empty())
				{
					string msg = "You are using a new [yt-dlp.exe].\r\n\r\n";
					msg += "current version: " + version;
					HostMessageBox(msg, "[yt-dlp] INFO", 2, 0);
					cfg.setStr("MAINTENANCE", "ytdlp_hash", hash);
					error = 0;
				}
				else if (hash != hash0)
				{
					if (error >= 0)
					{
						string msg =
						"Your [yt-dlp.exe] is different from before.\r\n\r\n"
						"Current version: " + version + "\r\n\r\n"
						"You can continue playback if you replaced it intentionally.";
						if (cfg.getInt("MAINTENANCE", "update_ytdlp") > 0)
						{
							msg += "\r\nThe [update_ytdlp] setting will be reset.";
						}
						HostMessageBox(msg, "[yt-dlp] ALERT", 0, 0);
						error = -1;
					}
					else
					{
						cfg.setStr("MAINTENANCE", "ytdlp_hash", hash);
						error = 0;
					}
				}
				else
				{
					error = 0;
				}
			}
		}
	}
	
	int checkFile(bool checkHash)
	{
		_checkFileInfo();
		if (checkHash) _checkFileHash();
		
		if (error != 0) cfg.deleteKey("MAINTENANCE", "update_ytdlp");
		if (error > 0) version = "";
		return error;
	}
	
	void criticalError()
	{
		version = "";
		error = 3;
		cfg.setInt("MAINTENANCE", "critical_error", 1, false);
		cfg.deleteKey("MAINTENANCE", "update_ytdlp");
		string msg = "Your [yt-dlp.exe] did not work as expected.\r\n";
		HostPrintUTF8("\r\n[yt-dlp] CRITICAL ERROR! " + msg);
		msg += "After confirming there are no problems, set [critical_error] to 0 in the config file and reload the script.";
		HostMessageBox(msg, "[yt-dlp] CRITICAL ERROR", 3, 2);
	}
	
	void updateVersion()
	{
		checkFile(false);
		if (error != 0) return;
		HostIncTimeOut(10000);
		string output = HostExecuteProgram(qt(fileExe), " -U");
		if (output.find("Latest version:") < 0 && output.find("ERROR:") < 0)
		{
			HostPrintUTF8("[yt-dlp] ERROR! No update info.\r\n");
			criticalError();
			return;
		}
		int pos = output.findLastNotOf("\r\n");
		output = output.Left(pos + 1);
		HostMessageBox(output, "[yt-dlp] INFO: Update yt-dlp.exe", 2, 1);
		error = -1;
		checkFile(true);
	}
	
	bool _checkLogCommand(string log)
	{
		string errMsg = "\nyt-dlp.exe: error: ";
		int pos1 = sch.findI(log, errMsg);
		if (pos1 >= 0)
		{
			pos1 += errMsg.size();
			int pos2 = sch.findEol(log, pos1);
			string msg = log.substr(pos1, pos2 - pos1);
			if (sch.findI(msg, "unsupported browser") >= 0)
			{
				string browser = cfg.getStr("COOKIE", "cookie_browser");
				if (!browser.empty())
				{
					msg =
					browser + " is not supported as a browser.\r\n"
					"Use Firefox as [cookie_browser] or use [cookie_file] option.\r\n\r\n"
					"The [cookie_browser] setting will be commented out.";
					HostMessageBox(msg, "[yt-dlp] ERROR: Command", 0, 0);
					cfg.cmtoutKey("COOKIE", "cookie_browser");
					return true;
				}
			}
			msg = log.substr(pos1, pos2 - pos1);
			HostMessageBox(msg, "[yt-dlp] ERROR: Command", 0, 0);
			return true;
		}
		if (sch.findI(log, "[debug] Command-line config:") < 0)
		{
			HostPrintUTF8("[yt-dlp] ERROR! No command line info.\r\n");
			criticalError();
			return true;
		}
		
		return false;
	}
	
	bool _checkLogVersion(string log)
	{
		int pos1 = log.find("\n[debug] yt-dlp version");
		if (pos1 >= 0)
		{
			pos1 += 1;
			int pos2 = sch.findEol(log, pos1);
			string str = log.substr(pos1, pos2 - pos1);
			if (str.find(version) >= 0)
			{
				return false;
			}
		}
		HostPrintUTF8("[yt-dlp] ERROR! Wrong version.\r\n");
		criticalError();
		return true;
	}
	
	bool _checkLogBrowser(string log)
	{
		string msg = "";
		string op;
		int pos1 = sch.findRegExp(log, "(?i)^error: could not ([^\r\n]+?) cookies? database", op);
		if (pos1 >= 0)
		{
			string browser = cfg.getStr("COOKIE", "cookie_browser");
			if (!browser.empty())
			{
				if (op.find("copy") >= 0)
				{
					msg =
					"Cannot copy cookie database from " + browser + ".\r\n"
					"Use Firefox as [cookie_browser] or use [cookie_file] option.\r\n";
				}
				else if (op.find("find") >= 0)
				{
					msg = "Cannot find cookie database of " + browser + ".\r\n";
				}
			}
			if (msg.empty())
			{
				pos1 = sch.findLineTop(log, pos1);
				int pos2 = sch.findEol(log, pos1);
				msg = log.substr(pos1, pos2 - pos1) + "\r\n";
			}
		}
		if (cfg.getStr("COOKIE", "cookie_browser").MakeLower() == "safari")
		{
			msg =
			"Safari is not a supported browser on Windows.\r\n"
			"Use Firefox as [cookie_browser] or use [cookie_file] option.\r\n";
		}
		if (!msg.empty())
		{
			msg += "\r\nThe [cookie_browser] setting will be commented out.";
			HostMessageBox(msg, "[yt-dlp] ERROR: Cookie browser", 0, 0);
			cfg.cmtoutKey("COOKIE", "cookie_browser");
			return true;
		}
		return false;
	}
	
	bool _checkLogGeoRestriction(string log, string url)
	{
		if (sch.findRegExp(log, "(?i)Error: [^\r\n]* not available [^\r\n]+ geo restriction") >= 0)
		{
			string msg = "This video/sound is not available from your location due to geo restriction.\r\n\r\n" + url;
			HostMessageBox(msg, "[yt-dlp] INFO", 2, 0);
			return true;
		}
		return false;
	}
	
	int _checkLogUpdate(string log)
	{
		if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 1)
		{
			int pos1 = log.find("\n[debug] Downloading yt-dlp.exe ");
			if (pos1 >= 0)
			{
				pos1 = log.find("\n", pos1 + 1);
				if (pos1 >= 0)
				{
					pos1 += 1;
					string msg;
					if (log.substr(pos1, 7) == "ERROR: ")
					{
						msg =
						"A newer version of [yt-dlp.exe] was found on the website,\r\n"
						"but the automatic update failed.\r\n\r\n";
						pos1 += 7;
						if (sch.findI(log, "Unable to write", pos1) == pos1)
						{
							msg +=
							"Unable to overwrite [yt-dlp.exe] in:\r\n"
							+ fileExe + "\r\n\r\n"
							"Replace it manually or try running PotPlayer with administrator privileges.\r\n\r\n";
						}
						else
						{
							int pos2 = sch.findEol(log, pos1);
							msg += log.substr(pos1, pos2 - pos1) + "\r\n\r\n";
						}
						msg += "The [update_ytdlp] setting will be reset.";
						HostMessageBox(msg, "[yt-dlp] ERROR: Auto update", 0, 0);
						cfg.setInt("MAINTENANCE", "update_ytdlp", 0);
						return -1;
					}
					else
					{
						int pos2 = sch.findEol(log, pos1);
						msg = log.substr(pos1, pos2 - pos1);
						HostMessageBox(msg, "[yt-dlp] INFO: Auto update", 2, 0);
						error = -1;
						checkFile(true);
						return 1;
					}
				}
			}
		}
		return 0;
	}
	
	bool _checkLiveOffline(string log, string url)
	{
		if (sch.findRegExp(log, "(?i)^ERROR: [^\r\n]* (not currently live|off ?line)") >= 0)
		{
			string msg = "This channel is not live now.\r\n\r\n" + url;
			HostMessageBox(msg, "[yt-dlp] INFO", 2, 0);
			return true;
		}
		return false;
	}
	
	bool _checkLiveFromStart(string log, string options)
	{
		if (sch.findRegExp(log, "(?i)^ERROR: ?\\[twitch:stream\\][^\r\n]*--live-from-start") >= 0)
		{
			if (options.find(" --live-from-start") >= 0)
			{
				return true;
			}
		}
		return false;
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
				pos1 = sch.findLineTop(log, pos1);
				int pos2 = sch.findEol(log, pos1);
				if (sch.findI(log, "[debug]", pos1) != pos1 && sch.findI(log, "  File \"", pos1) != pos1)
				{
					outStr += log.substr(pos1, pos2 - pos1) + "\r\n";
				}
				pos1 = pos2;
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
			log.erase(pos, _s.size());
			return true;
		}
		return false;
	}
	
	array<string> _getEntries(const string str, uint &out posLog)
	{
		array<string> entries;
		posLog = 0;
		
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
			posLog = pos2 + 1;
			pos = str.find("\n{", pos2);
		} while (pos > top0);
		
		return entries;
	}
	
	array<string> exec(string url, int playlistMode)
	{
		checkFile(true);
		if (error != 0) return {};
		
		bool checkBiliPart = false;
		if (_isPotentialBiliPart(url))
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
			
			if (cfg.csl > 0) HostPrintUTF8("\r\n[yt-dlp] " + (playlistMode < 0 ? "Retry " : "") + "Parsing... - " + qt(url) + "\r\n");
			
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
			
			if (playlistMode == 0)	// Exclude the case playlistMode == -1
			{
				if (_IsUrlSite(url, "twitch.tv"))	// for twitch
				{
					if (cfg.getInt("FORMAT", "live_as_vod") == 1)
					{
						options += " --live-from-start";
					}
				}
				/*
				else if (_IsUrlSite(url, "youtube"))
				{
					if (cfg.getInt("YOUTUBE", "youtube_live") == 2)
					{
						// doesn't work
						options += " --live-from-start";
					}
				}
				*/
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
			
			options += " -R 3 --ignore-no-formats-error";
		}
		
		bool hasCookie = _addOptionsCookie(options);
		
		if (_IsUrlSite(url, "youtube"))
		{
			string youtubeArgs = _getYoutubeArgs(hasCookie);
			options += " --extractor-args " + qt(youtubeArgs);
		}
		
		_addOptionsNetwork(options);
		
		if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 1)
		{
			options += " -U";
		}
		
		options += " -j";	// "-j" must be in lower case
		
		// Execute
		string output;
		if (playlistMode <= 0)
		{
			options += " -v";
			options += " -- " + url;
			output = HostExecuteProgram(qt(fileExe), options);
		}
		else
		{
			output = _extractPlaylist(url, options);
		}
		
		uint posLog = 0;
		array<string> entries = _getEntries(output, posLog);
		string log = output.substr(posLog).TrimLeft("\r\n");
		
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
		if (_checkLogVersion(log)) return {};
		if (_checkLogBrowser(log)) return {};
		if (_checkLogGeoRestriction(log, url)) return {};
		if (_checkLiveOffline(log, url)) return {};
		
		if (_checkLiveFromStart(log, options))
		{
			return exec(url, -1);	// Retry without --live-from-start
		}
		
		_checkLogUpdate(log);
		
		if (entries.size() == 0)
		{
			if (output.find("ERROR") >= 0)
			{
				if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Unsupported. - " + qt(url) + "\r\n");
			}
			else if (sch.findI(output, "downloading 0 items") >= 0)
			{
				if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] No entries in this playlist. - " + qt(url) + "\r\n");
			}
			else
			{
				HostPrintUTF8("[yt-dlp] ERROR! No data or info.\r\n");
				// criticalError();
			}
		}
		
		return entries;
	}
	
	array<string> exec2(array<string> urls, int singleMode)
	{
		if (urls.size() == 0) return {};
		
		if (cfg.csl > 0)
		{
			string msg;
			msg += "\r\n[yt-dlp] ";
			if (singleMode == 4)	// BilibiliPart
			{
				msg += "Collecting playlist thumbnails... - ";
			}
			else if (singleMode > 0)
			{
				msg += "Collecting playlist metadata... - ";
			}
			else
			{
				msg += "Extracting nested playlist entries... - ";
			}
			msg += qt(urls[0]);
			if (urls.size() == 2) msg += " and " + qt(urls[1]) + ".\r\n";
			else if (urls.size() > 2) msg += " and " + (urls.size() - 1) + " URLs.\r\n";
			HostPrintUTF8(msg);
		}
		
		string options = "";
		
		//if (singleMode < 2)
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
			if (singleMode > 0) options += " -I 1";
			options += " --no-playlist";
		}
		
		options += " -R 3 --ignore-no-formats-error";
		
		_addOptionsNetwork(options);
		
		bool hasCookie = _addOptionsCookie(options);
		
		if (_IsUrlSite(urls[0], "youtube"))
		{
			string youtubeArgs = _getYoutubeArgs(hasCookie);
			options += " --extractor-args " + qt(youtubeArgs);
		}
		
		options += " -j";	// "-j" must be in lower case
		
		// execute
		string output;
		if (singleMode > 0)
		{
			output = _getMetadata(urls, options, singleMode);
		}
		else
		{
			output = _extractPlaylist2(urls, options);
		}
		
		uint posLog = 0;
		array<string> entries = _getEntries(output, posLog);
		
		if (cfg.csl == 3)
		{
			HostPrintUTF8(output);
		}
		
		return entries;
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
		//options += " --retry-sleep linear=1::2";
		
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
		int pos1 = 0;
		do {
			string c = data.substr(pos1, 1);
			if (c == "{")
			{
				cnt++;
				pos1 = sch.findNextLineTop(data, pos1);
			}
			else if (eraseMessage)
			{
				sch.eraseLine(data, pos1);
			}
			else
			{
				pos1 = sch.findNextLineTop(data, pos1);
			}
		} while (pos1 >= 0 && pos1 < int(data.size()));
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
			output = HostExecuteProgram(qt(fileExe), " -v" + options + " -- " + url);
			
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
			bool youtubeChannelTop = _isYoutubeChannelTop(url);
			if (youtubeChannelTop)
			{
				// Devide the youtube channel top into video-type tabs
				// for devided downloads.
				if (url.Right(1) != "/") url += "/";
				url = url + "videos " + url + "streams " + url + "shorts";
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
				string addOutput = HostExecuteProgram(qt(fileExe), wholeOption);
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
		if (urls.size() == 0) return "";
		string output;
		string cnctUrl = "";
		for (uint i = 0; i < urls.size(); i++) cnctUrl += " " + urls[i];
		
		int waitTime = cfg.getInt("TARGET", "playlist_items_timeout");
		if (waitTime == 0)
		{
			HostIncTimeOut(2000000);
			uint startTime = HostGetTickCount();
			output = HostExecuteProgram(qt(fileExe), options + " --" + cnctUrl);
			
			if (cfg.csl > 0)
			{
				uint cnt = _countJson(output, false);
				int elapsedTime = (HostGetTickCount() - startTime)/1000;
				if (elapsedTime < 0) elapsedTime = -1;
				string msg;
				{
					msg = "  count: " + cnt;
					msg += "\t\ttime: " + elapsedTime + " sec";
					HostPrintUTF8(msg);
					if (cnt == 0) msg = "  Failed to get.\r\n";
					else msg = "  Complete.\r\n";
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
				string addOutput = HostExecuteProgram(qt(fileExe), options + " --" + cnctUrl);
				uint addCnt = _countJson(addOutput, false);
				if (addCnt > 0)
				{
					output += addOutput;
					cnt += addCnt;
					int elapsedTime = (HostGetTickCount() - startTime)/1000;
					if (elapsedTime < 0) elapsedTime = -1;
					if (cfg.csl > 0)
					{
						string msg = "  count: " + cnt;
						msg += "\t\ttime: " + elapsedTime + " sec";
						HostPrintUTF8(msg);
					}
					if (addCnt < unitIdx) break;
					if (elapsedTime < 0 || elapsedTime >= waitTime)
					{
						timeout = true;
						break;
					}
					continue;
				}
				break;
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
		if (urls.size() == 0) return "";
		string output;
		
		int waitTime;
		string msg1;
		if (singleMode >= 2)
		{
			waitTime = cfg.getInt("TARGET", "playlist_metadata_timeout");
			if (waitTime < 0)
			{
				cfg.setInt("TARGET", "playlist_metadata_timeout", 0);
				waitTime = 0;
			}
			msg1 = "  playlist_metadata_timeout: " + waitTime + " sec";
		}
		else if (singleMode == 1)
		{
			// for responsive websites like youtube
			waitTime = cfg.getInt("TARGET", "playlist_items_timeout");
			msg1 = "  playlist_items_timeout: " + waitTime + " sec";
		}
		else
		{
			return "";
		}
		
		uint unitIdx = 10;
		if (waitTime == 0 || urls.size() <= unitIdx)
		{
			string cnctUrl = "";
			for (uint i = 0; i < urls.size(); i++) cnctUrl += " " + urls[i];
			
			HostIncTimeOut(2000000);
			uint startTime = HostGetTickCount();
			output = HostExecuteProgram(qt(fileExe), options + " --" + cnctUrl);
			
			if (cfg.csl > 0)
			{
				uint cnt = _countJson(output, false);
				int elapsedTime = (HostGetTickCount() - startTime)/1000;
				if (elapsedTime < 0) elapsedTime = -1;
				string msg;
				{
					msg = "  count: " + cnt;
					msg += "\t\ttime: " + elapsedTime + " sec";
					HostPrintUTF8(msg);
					if (cnt == 0) msg = "  Failed to get.\r\n";
					else msg = "  Complete.\r\n";
				}
				HostPrintUTF8(msg);
			}
		}
		else	// waitTime > 0
		{
			if (cfg.csl > 0) HostPrintUTF8(msg1);
			uint cnt = 0;
			int complete = 0;
			uint startTime = HostGetTickCount();
			for (uint i = 0; i < urls.size(); i += unitIdx)
			{
				HostIncTimeOut(300000);
				string cnctUrl = "";
				for (uint j = i; j < i + unitIdx; j++)
				{
					cnctUrl += " " + urls[j];
					if (j >= urls.size() - 1) {complete = 1; break;}
				}
				string addOutput = HostExecuteProgram(qt(fileExe), options + " --" + cnctUrl);
				uint addCnt = _countJson(addOutput, false);
				if (addCnt > 0)
				{
					output += addOutput;
					cnt += addCnt;
					int elapsedTime = (HostGetTickCount() - startTime)/1000;
					if (elapsedTime < 0) elapsedTime = -1;
					if (cfg.csl > 0)
					{
						string msg = "  count: " + cnt;
						msg += "\t\ttime: " + elapsedTime + " sec";
						HostPrintUTF8(msg);
					}
					if (complete > 0) break;
					if (elapsedTime < 0 || elapsedTime >= waitTime) break;
					continue;
				}
			}
			if (cfg.csl > 0)
			{
				string msg2;
				if (cnt == 0) msg2 = "  Failed to get.\r\n";
				else if (complete > 0) msg2 = "  Complete.\r\n";
				else msg2 = "  Time out.\r\n";
				HostPrintUTF8(msg2);
			}
		}
		return output;
	}
	
};

YTDLP ytd;

//---------------------- END of class YTDLP ------------------------



void OnInitialize()
{
	// Called when loading script at first
	if (SCRIPT_VERSION.Right(1) == "#") HostOpenConsole();	// debug version
	cfg.loadFile();
	ytd.checkFile(false);
}


string GetTitle()
{
	// Called when loading script and closing the config panel with ok button
	string scriptName = "yt-dlp " + SCRIPT_VERSION;
	if (ytd.error > 0)
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
		HostMessageBox(msg, "[yt-dlp] ERROR: Default config file", 3, 0);
	}
	if (noCurl == 1)
	{
		noCurl = 2;
		string msg = 
		"CURL command not found.\r\n"
		"Some features do not work if they need \"curl.exe\".\r\n"
		"Please place \"curl.exe\" in the system32 folder or in any folder accessible to the extension.";
		HostMessageBox(msg, "[yt-dlp] CAUTION: No CURL Command", 0, 1);
	}
}


string GetDesc()
{
	// Called when opening info panel
	if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 2)
	{
		cfg.setInt("MAINTENANCE", "update_ytdlp", 0);
		ytd.updateVersion();
	}
	else
	{
		ytd.checkFile(true);
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
	
	switch (ytd.error)
	{
		case 1:
			info += "\r\n\r\n"
			"| Please place [yt-dlp.exe] in Module folder\r\n"
			"| under PotPlayer's program folder.\r\n";
			break;
		case 2:
			info += "\r\n\r\n"
			"| Your [yt-dlp.exe] may not be valid.\r\n"
			"| Please check in PotPlayer's Module folder\r\n"
			"| and replace it with a proper one.\r\n";
			break;
		case 3:
			info += "\r\n\r\n"
			"| Your [yt-dlp.exe] did not work as expected.\r\n"
			"| After confirming no issues, reset [critical_error]\r\n"
			"| in the config file and reload the script.\r\n";
			break;
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
			exts.insertAt(exts.size(), extsImage);
		}
		if (type & 0x10 > 0)	// video
		{
			array<string> extsVideo = {"avi", "wmv", "wmp", "wm", "asf", "mpg", "mpeg", "mpe", "m1v", "m2v", "mpv2", "mp2v", "ts", "tp", "tpr", "trp", "vob", "ifo", "ogm", "ogv", "mp4", "m4v", "m4p", "m4b", "3gp", "3gpp", "3g2", "3gp2", "mkv", "rm", "ram", "rmvb", "rpm", "flv", "swf", "mov", "qt", "amr", "nsv", "dpg", "m2ts", "m2t", "mts", "dvr-ms", "k3g", "skm", "evo", "nsr", "amv", "divx", "webm", "wtv", "f4v", "mxf"};
			exts.insertAt(exts.size(), extsVideo);
		}
		if (type & 0x100 > 0)	// audio
		{
			array<string> extsAudio = {"wav", "wma", "mpa", "mp2", "m1a", "m2a", "mp3", "ogg", "m4a", "aac", "mka", "ra", "flac", "ape", "mpc", "mod", "ac3", "eac3", "dts", "dtshd", "wv", "tak", "cda", "dsf", "tta", "aiff", "aif", "aifc" "opus", "amr"};
			exts.insertAt(exts.size(), extsAudio);
		}
		if (type & 0x1000 > 0)	// playlist
		{
			array<string> extsPlaylist = {"m3u8", "m3u", "asx", "pls", "wvx", "wax", "wmx", "cue", "mpls", "mpl", "xspf", "mpd", "dpl"};
				// exclude "xml", "rss"
			exts.insertAt(exts.size(), extsPlaylist);
		}
		if (type & 0x10000 > 0)	// subtitles
		{
			array<string> extsSubtitles = {"smi", "srt", "idx", "sub", "sup", "psb", "ssa", "ass", "txt", "usf", "xss.*.ssf", "rt", "lrc", "sbv", "vtt", "ttml", "srv"};
			exts.insertAt(exts.size(), extsSubtitles);
		}
		if (type & 0x100000 > 0)	// compressed
		{
			array<string> extsCompressed = {"zip", "rar", "tar", "7z", "gz", "xz", "cab", "bz2", "lzma", "rpm"};
			exts.insertAt(exts.size(), extsCompressed);
		}
		if (type & 0x1000000 > 0)	// xml, rss
		{
			array<string> extsXml = {"xml", "rss"};
			exts.insertAt(exts.size(), extsXml);
		}
	}
	
	if (exts.find(ext) >= 0) return true;
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


string _getYoutubeChannelUrl(string url)
{
	if (url.find(" ") >= 0) return "";
	string channel;
	bool isChannel = false;
	if (sch.findRegExp(url, "(?i)^https?://www\\.youtube\\.com/@[^/?#]+", channel) == 0) isChannel = true;
	else if (sch.findRegExp(url, "(?i)^https?://www\\.youtube\\.com/channel/[-\\w]+", channel) == 0) isChannel = true;
	if (isChannel) return channel;
	return "";
}

bool _isYoutubeChannelTop(string url)
{
	string channel = _getYoutubeChannelUrl(url);
	if (!channel.empty())
	{
		channel += "/";
		if (url.Right(1) != "/") url += "/";
		if (url.size() == channel.size()) return true;
	}
	return false;
}

string _getYoutubeChannelTab(string url)
{
	string channel = _getYoutubeChannelUrl(url);
	if (!channel.empty())
	{
		if(url.substr(channel.size(), 1) == "/")
		{
			string tab = url.substr(channel.size() + 1);
			if (tab.findFirstOf("/?& ") < 0)
			{
				tab.MakeLower();
				return tab;
			}
		}
	}
	return "";
}

bool _isYoutubeTabPlaylistType(string url)
{
	array<string> playlistTabs = {"featured", "playlists", "releases", "podcasts"};
	string tab = _getYoutubeChannelTab(url);
	if (!tab.empty())
	{
		if (playlistTabs.find(tab) >= 0) return true;
	}
	return false;
}


int _checkBilibiliPart(string url)
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

bool _isPotentialBiliPart(string url)
{
	if (_checkBilibiliPart(url) == 0) return true;
	return false;
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
		// Not available to dynamic pages that change playlists
	}
	//options += " --max-filesize " + fileSize;
	if (isInsecure)
	{
		options += " -k";
	}
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
		if (cfg.csl >= 2)
		{
			HostPrintUTF8("\r\n http " + (range < 0 ? "header" : "content") + " -------------------");
			HostPrintUTF8(data);
			HostPrintUTF8("--------------------------\r\n");
		}
	}
	
	if (!data.empty())
	{
		// Get only the last header if data includes multiple headers with redirect.
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
	string UserAgent;
	//string UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:142.0) Gecko/20100101 Firefox/142.0";
	uintptr http = HostOpenHTTP(url, UserAgent);
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
	
	string data = cfg.getStr("TARGET", "website_playlist_each");
	data.MakeLower();
	array<dictionary> dicsMode;
	
	int pos1 = -1;
	int pos2 = 0;
	while (pos2 > pos1)
	{
		pos1 = pos2;
		array<dictionary> match;
		pos2 = sch.regExpParse(data, "([^: ,]+): ?(\\d)\\b", match, pos1);
		if (pos2 >= 0)
		{
			dictionary dic;
			dic["name"] = string(match[1]["str"]);
			dic["mode"] = parseInt(string(match[2]["str"]));
			dicsMode.insertLast(dic);
			string _s = string(match[0]["str"]);
			pos2 += _s.size();
			if (data.substr(pos2, 1) != ",") break;
		}
	}
	
	string domain = _GetUrlDomain(url);
	for (uint i = 0; i < dicsMode.size(); i++)
	{
		string name = string(dicsMode[i]["name"]);
		if (domain.find(name) >= 0)
		{
			int _mode = int(dicsMode[i]["mode"]);
			if (_mode >= 0 && _mode <= 2) mode = _mode;
			break;
		}
	}
	
	return mode;
}


bool _PlayitemCheckBase(string url)
{
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


bool _CheckFileExt(string path)
{
	string ext = HostGetExtension(path);
	if (ext.empty()) return true;	// No file extension
	if (!_IsExtType(ext, 0x11111)) return true;	// unknown file extension
	return false;
}

uint startTimeGlobal = 0;

bool _CheckStartTime(uint startTimeLocal, string url)
{
	if (startTimeLocal != startTimeGlobal)
	{
		// startTimeGlobal has been changed because the user started another task,
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
		if (!_CheckFileExt(url))
		{
			startTimeGlobal = 0;
		}
		return false;
	}
	//if (!_PlayitemCheckBase2(url)) return false;
	
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
		if (enableYoutube != 2 && enableYoutube != 3) return false;
	}
	
	return (_WebsitePlaylistMode(url) > 0);
}


string _CutoffDesc(string desc)
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
		desc = sch.cutoffDesc(desc, uint(titleMaxLen));
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


bool _checkUrlPlaylist(dictionary dic)
{
	int playlistSelfCnt = int(dic["playlist_self_count"]);
	if (playlistSelfCnt > 0) return true;
	
	string url = string(dic["url"]);
	if (_IsUrlSite(url, "youtube"))
	{
		url.MakeLower();
		if (url.find("?list=") > 0) return true;
		string channel = _getYoutubeChannelUrl(url);
		if (!channel.empty()) return true;
	}
	
	return false;
}


string _GetJsonUrl(string jsonData)
{
	string url = HostRegExpParse(jsonData, "\"webpage_url\": ?\"([^\"]+)\"");
	return url;
}

int _GetJsonPlaylistCount(string jsonData)
{
	int playlistCnt = parseInt(HostRegExpParse(jsonData, "\"playlist_count\": ?(\\d+),"));
	return playlistCnt;
}

array<string> _MakeUrlArrayAll(array<string> entries)
{
	array<string> urls = {};
	for (uint i = 0; i < entries.size(); i++)
	{
		string url = _GetJsonUrl(entries[i]);
		if (!url.empty()) urls.insertLast(url);
	}
	return urls;
}

array<string> _MakeUrlArrayMetadata(array<dictionary> dicsEntry, array<uint> &inout arrIdx)
{
	array<string> urls = {};
	arrIdx = {};
	for (uint i = 0; i < dicsEntry.size(); i++)
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
		else if (_checkUrlPlaylist(dicsEntry[i]))
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
	for (uint i = 0; i < dicsEntry.size(); i++)
	{
		if (!string(dicsEntry[i]["title"]).empty())
		{
			if (_checkUrlPlaylist(dicsEntry[i]))
			{
				urls.insertLast(string(dicsEntry[i]["url"]));
				arrIdx.insertLast(i);
			}
		}
	}
	return urls;
}

dictionary _PlaylistParse(string json, bool forcePlaylist, string imgUrl)
{
	if (json.empty()) return {};
	
	dictionary dic;
	JsonReader reader;
	JsonValue root;
	if (reader.parse(json, root) && root.isObject())
	{
		string url = _GetJsonValueString(root, "original_url");
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
				title = _ReviseDesc(title);
				title = _CutoffDesc(title);
				dic["title"] = title;
			}
		}
		string playlistTitle = _GetJsonValueString(root, "playlist_title");
		if (!playlistTitle.empty())
		{
			if (baseName != playlistTitle + ext2)
			{
				playlistTitle = _ReviseDesc(playlistTitle);
				playlistTitle = _CutoffDesc(playlistTitle);
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
				// Convert to format "hh:mm:ss" by adding "0:" to the top.
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
	}
	return dic;
}


array<dictionary> PlaylistParse(const string &in path)
{
	// Called after PlaylistCheck if it returns true
//HostPrintUTF8("PlaylistParse - " + path);
	
	uint startTimeLocal = HostGetTickCount();
	startTimeGlobal = startTimeLocal;
	
	if (cfg.csl > 0) HostOpenConsole();
	
	array<dictionary> dicsEntry;
	
	string plUrl = _ReviseUrl(path);
	
	if (_IsUrlSite(plUrl, "shoutcast"))
	{
		if (cfg.getInt("TARGET", "shoutcast_playlist") == 1)
		{
			shoutpl.passPlaylist(plUrl, dicsEntry);
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
	
	if (_CheckStartTime(startTimeLocal, path)) return {};
	
	int playlistMode = _WebsitePlaylistMode(plUrl);
	
	array<string> entries = ytd.exec(plUrl, playlistMode);
	if (entries.size() == 0) return {};
	
	if (_CheckStartTime(startTimeLocal, path)) return {};
	
	bool forcePlaylist = false;
	if (_IsUrlSite(plUrl, "youtube")) forcePlaylist = true;;
		// For YouTube, this extension always treats a URL as a playlist
		// to prevent the built-in YouTube extension from changing the playlist state.
		// If a URL refers to both a video and a playlist
		// (e.g., https://www.youtube.com/watch?v=XXXXX&list=YYYYY),
		// this extension uses the --no-playlist option to ignore the playlist
		// and treats the URL as a playlist containing only that single video.
	
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
	
	if (_isYoutubeTabPlaylistType(plUrl))
	{
		if (cfg.getInt("YOUTUBE", "keep_tab_playlist") != 1)
		{
			// Extract all nested playlists.
			array<string> urls = _MakeUrlArrayAll(entries);
			entries = ytd.exec2(urls, 0);
		}
		if (_CheckStartTime(startTimeLocal, path)) return {};
	}
	
	for (uint i = 0; i < entries.size(); i++)
	{
		dictionary dic = _PlaylistParse(entries[i], forcePlaylist, imgUrl);
		dicsEntry.insertLast(dic);
	}
	
	array<uint> arrIdx = {};
	array<string> urls = _MakeUrlArrayMetadata(dicsEntry, arrIdx);
	if (urls.size() > 0)
	{
		bool noTitle = string(dicsEntry[0]["title"]).empty();
		int singleMode = noTitle ? 2 : 1;
		if (_isPotentialBiliPart(urls[0])) singleMode = 3;
		
		array<string> _entries = ytd.exec2(urls, singleMode);
		
		if (_CheckStartTime(startTimeLocal, path)) return {};
		
		for (uint i = 0; i < _entries.size(); i++)
		{
			dictionary dic1 = _PlaylistParse(_entries[i], true, imgUrl);
			dictionary @dic0 = dicsEntry[arrIdx[i]];
			
			int playlistIdx = int(dic1["playlist_index"]);
			bool selfPlaylist = (playlistIdx > 0);
			if (selfPlaylist)	// for playlist
			{
				int playlistSelfCnt = int(dic1["playlist_count"]);
				if (playlistSelfCnt > 0)
				{
					dic0["playlist_self_count"] = playlistSelfCnt;
				}
				
				string note;
				{
					note += "<Playlist";
					if (playlistSelfCnt > 0)
					{
						note += ": " + playlistSelfCnt;
					}
					note += ">";
					string extractor = string(dic1["extractor"]);
					if  (!_isGeneric(extractor))
					{
						note += " @" + extractor;
					}
				}
				dic0["author"] = note;
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
		
		if (cfg.getInt("TARGET", "playlist_without_metadata") != 1)
		{
			for (int i = 0; i < int(dicsEntry.size()); i++)
			{
				if (string(dicsEntry[uint(i)]["title"]).empty())
				{
					dicsEntry.removeAt(i);
					i--;
				}
			}
		}
		
		if (singleMode == 3)	// BilibiliPart thumbnail
		{
			array<uint> arrIdx2 = {};
			array<string> urls2 = _MakeUrlArrayMetadata2(dicsEntry, arrIdx2);
			if (urls2.size() > 0)
			{
				array<string> _entries2 = ytd.exec2(urls2, 4);
				if (_CheckStartTime(startTimeLocal, path)) return {};
				for (uint i = 0; i < _entries2.size(); i++)
				{
					dictionary dic2 = _PlaylistParse(_entries2[i], true, "");
					dictionary @dic0 = dicsEntry[arrIdx2[i]];
					string thumb = string(dic2["thumbnail"]);
					if (!thumb.empty()) dic0["thumbnail"] = thumb;
				}
			}
		}
	}
	
	return dicsEntry;
}


bool PlayitemCheck(const string &in path)
{
	// Called when an item is being opened after PlaylistCheck or PlaylistParse.
//HostPrintUTF8("PlayitemCheck");
	
	string url = _ReviseUrl(path);
	url.MakeLower();
	
	if (!_PlayitemCheckBase(url))
	{
		// Reset startTimeGlobal only if a local clip is opened.
		// Online content calls this function not only when being opened, but also when just reloading the thumbnail.
		if (!_CheckFileExt(url))
		{
			startTimeGlobal = 0;
		}
		return false;
	}
	
	string ext = _GetUrlExtension(url);
	if (ext == "rss") return false;
	if (_IsExtType(ext, 0x111000))	// playlist or other files
	{
		if (ext == "m3u8")
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
HostPrintUTF8("hShell: " + hShell);
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
	HostExecuteProgram(potplayerExe, options);
	//_RunAsync(potplayerExe, options);
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
		if (month.size() == 1) month = "0" + month;
		if (day.size() == 1) day = "0" + day;
		return year + "-" + month + "-" + day;
	}
	return "";
}


string _ReviseDate(string date)
{
	if (date.size() != 8) return date;
	string outDate = HostRegExpParse(date, "^(\\d+)$");
	if (outDate.size() != 8) return date;
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
	// These sites always add the author name to the title top.
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
				if (s3.size() == 2)	// country code top level domain
				{
					if (s2.size() < 4)
					{
						if (!s1.empty() && s1 != "www.")
						{
							// Get the domain name up to 3rd level.
							domain = s1 + s2 + "." + s3;
						}
					}
				}
				if (domain.empty())
				{
					// In most cases, get the domain name up to 2nd level.
					domain = s2 + "." + s3;
				}
			}
		}
	}
	return domain;
}


string _ReviseUrl(string url)
{
	if (url.Left(1) == "<")
	{
		// Remove the time range if exists
		int pos = url.find(">", 0);
		if (pos >= 0) url = url.substr(pos + 1);
	}
	
	if (url.Left(ytd.SCHEME.size()) == ytd.SCHEME)
	{
		url = url.substr(ytd.SCHEME.size());
	}
	
	return url;
}


string _ReviseDesc(string desc)
{
	desc.replace("\\r\\n", "\n");
	desc.replace("\\n", "\n");
	//desc.replace("+", " ");
	
	// decode entity name
	desc.replace("&quot;", "\"");
	desc.replace("&apos;", "'");
	desc.replace("&amp;", "&");
	desc.replace("&lt;", "<");
	desc.replace("&gt;", ">");
	desc.replace("&nbsp;", " ");
	desc.replace("&shy;", " ");
	desc.replace("&copy;", "©");
	desc.replace("&reg;", "®");
	
	desc = sch.decodeNumericCharRefs(desc);
	
	// Remove the top LF
	int lfPos = desc.find("\n");
	if (lfPos >= 0 && lfPos < 4) desc.erase(lfPos, 1);
	
	return desc;
}


bool _SelectAutoSub(string code, array<dictionary> dicsSub)
{
	if (code.empty()) return false;
	
	string lang;
	
	int pos = sch.findI(code, "-orig");
	if (pos > 0) {
		// original language of contents
		lang = code.Left(pos);
	}
	else if (sch.findRegExp(code, "(?i)^" + sch.escapeReg(cfg.baseLang) + "\\b") >= 0)
	{
		// user's base language
		// If baseLang is "pt", both "pt-BR" and "pt-PT" are considered to be match.
		lang = code;
	}
	
	if (lang.empty()) return false;
	
	for (uint i = 0; i <dicsSub.size(); i++)
	{
		string code1;
		if (dicsSub[i].get("langCode", code1))
		{
			if (lang == code1) return false;	// duplicate
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
					
					// If the difference of bitrate is small, two audio quolities are considered the same.
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
		if (__IsSameQuality(dic, dics[i])) return true;
	}
	return false;
}


bool _CheckLangageName(string &inout note)
{
	// Return true if note is possible to be a language name.
	if (!note.empty())
	{
		array<string> _qualities = {
			"low", "medium", "high", "Default"
		};
		note.MakeLower();
		if (_qualities.find(note) < 0)
		{
			if (!HostRegExpParse(note, "\\w{20}", {}))
			{
				if (sch.findRegExp(note, "(?i)\\b(dash|hls)\\b") < 0)
				{
					int pos = note.find(" (default)");
					if (pos >= 0)
					{
						note.erase(pos, 10);
					}
					return true;
				}
			}
		}
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
	
	if (server == "IcecastCh" || httpHead == "\r\n")
	{
		// XSPF metadata for icecast
		string url2 = url;
		if (url2.Right(1) == "/") url2.erase(url2.size() - 1);
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
					title = _ReviseDesc(title);
					title = _CutoffDesc(title);
					MetaData["title"] = title;
					MetaData["author"] = title + " @" +server;
						// The station name is kept in the author field.
				}
				string genre = _GetDataField(data, "Stream Genre");
				string desc = _GetDataField(data, "Stream Description");
				string content;
				if (!genre.empty()) content = "{" + genre + "}";
				if (!desc.empty()) content = (!content.empty() ? " " : "") + desc;
				if (!content.empty())
				{
					content = _ReviseDesc(content);
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
			title = _ReviseDesc(title);
			title = _CutoffDesc(title);
			MetaData["title"] = title;
			MetaData["author"] = title + " @" +server;
				// The station name is kept in the author field.
		}
		string genre = _GetDataField(httpHead, "icy-genre");
		string desc = _GetDataField(httpHead, "icy-description");
		string content;
		if (!genre.empty()) content = "{" + genre + "}";
		if (!desc.empty()) content = (!content.empty() ? " " : "") + desc;
		if (!content.empty())
		{
			content = _ReviseDesc(content);
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
	// Check if a real file exists on the server with Content-Length.
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


string _GetPlaylistTitle(string url)
{
	string data = _GetHttpContent(url, 3, 8000);
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


string PlayitemParse(const string &in path, dictionary &MetaData, array<dictionary> &QualityList)
{
	// Called after PlayitemCheck if it returns true
//HostPrintUTF8("PlayitemParse - " + path);
	
	uint startTimeLocal = HostGetTickCount();
	startTimeGlobal = startTimeLocal;
	
	if (cfg.csl > 0) HostOpenConsole();
	
	string inUrl = _ReviseUrl(path);
	string outUrl;
	
	if (_GetUrlExtension(inUrl) == "m3u8")
	{
		if (!_CheckM3u8Hls(inUrl)) return "";
	}
	
	string httpHead = _GetHttpHeader(inUrl, 5);
	string fileType = _GetFileType(httpHead);
	if (!fileType.empty())
	{
		if (cfg.getInt("TARGET", "direct_file_info") == 1)
		{
			_SetFileInfo(MetaData, inUrl, httpHead, (fileType != "audio"));
			return inUrl;
		}
		return "";
	}
	
	if (_IsUrlSite(inUrl, "shoutcast"))
	{
		outUrl = shoutpl.parse(inUrl, MetaData, QualityList, true);
	}
	if (cfg.getInt("TARGET", "radio_info") == 1)
	{
		string _url = !outUrl.empty() ? outUrl : inUrl;
		if (_GetRadioInfo(MetaData, httpHead, _url)) outUrl = _url;
	}
	else if (outUrl.empty())
	{
		if (_CheckRadioServer(httpHead)) return "";
	}
	if (!outUrl.empty()) return outUrl;
	
	if (_CheckStartTime(startTimeLocal, path)) return "";
	
	array<string> entries = ytd.exec(inUrl, 0);
	if (entries.size() == 0) return "";
	
	if (_CheckStartTime(startTimeLocal, path)) return "";
	
	string json = entries[0];
	JsonReader reader;
	JsonValue root;
	if (!reader.parse(json, root) || !root.isObject())
	{
		HostPrintUTF8("[yt-dlp] ERROR! JSON data corrupted.\r\n");
		ytd.criticalError(); return "";
	}
	JsonValue jVersion = root["_version"];
	if (!jVersion.isObject())
	{
		HostPrintUTF8("[yt-dlp] ERROR! No version info.\r\n");
		ytd.criticalError(); return "";
	}
	else
	{
		string version = _GetJsonValueString(jVersion, "version");
		if (version.empty())
		{
			HostPrintUTF8("[yt-dlp] ERROR! No version info.\r\n");
			ytd.criticalError(); return "";
		}
	}
	string extractor = _GetJsonValueString(root, "extractor_key");
	if (extractor.empty()) extractor = _GetJsonValueString(root, "extractor");
	if (extractor.empty())
	{
		HostPrintUTF8("[yt-dlp] ERROR! No extractor.\r\n");
		ytd.criticalError(); return "";
	}
	bool isGeneric = _isGeneric(extractor);
	
	outUrl = _GetJsonValueString(root, "webpage_url");
	if (outUrl.empty())
	{
		HostPrintUTF8("[yt-dlp] ERROR! No webpage URL.\r\n");
		ytd.criticalError(); return "";
	}
	MetaData["webUrl"] = outUrl;
	
	bool isYoutube = _IsUrlSite(inUrl, "youtube");
	
	bool isLive = _GetJsonValueBool(root, "is_live");
	int concurrentViewCount = _GetJsonValueInt(root, "concurrent_view_count");
	if (concurrentViewCount > 0) isLive = true;
	if (!isLive)
	{
		string liveStatus = _GetJsonValueString(root, "live_status");
		if (liveStatus == "is_live") isLive = true;
	}
	if (isLive && isYoutube && cfg.getInt("YOUTUBE", "youtube_live") != 1)
	{
		if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] YouTube Live was passed through according to the \"youtube_live\" setting. - " + ytd.qt(inUrl) +"\r\n");
		return "";
	}
	
	string ext = _GetJsonValueString(root, "ext");
	if (!ext.empty()) MetaData["fileExt"] = ext;
	
	bool isAudioExt = _IsExtType(ext, 0x100);
	
	string thumb = _GetJsonValueString(root, "thumbnail");
	if (thumb.Right(4) == ".svg")
	{
		// .svg -> .png (PotPlayer does not support svg)
		thumb = thumb.Left(thumb.size() - 4) + ".png";
	}
	if (thumb.empty())
	{
		if (!isAudioExt)
		{
			thumb = inUrl;
		}
	}
	if (!thumb.empty()) MetaData["thumbnail"] = thumb;
	
	if (_CheckStartTime(startTimeLocal, path)) return "";
	
	int playlistIdx = _GetJsonValueInt(root, "playlist_index");
	if (playlistIdx > 0 && inUrl != outUrl)
	{
		// playlist url
		string playlistTitle = _GetJsonValueString(root, "playlist_title");
		if (playlistTitle.empty()) playlistTitle = _GetPlaylistTitle(inUrl);
		if (!playlistTitle.empty())
		{
			playlistTitle = _ReviseDesc(playlistTitle);
			playlistTitle = _CutoffDesc(playlistTitle);
			MetaData["title"] = playlistTitle;
		}
		string note = "";
		{
			int playlistSelfCnt = _GetJsonValueInt(root, "playlist_count");
			if (playlistSelfCnt < 1)
			{
				array<string> _entries = ytd.exec2({inUrl}, 3);
				if (_entries.size() == 1) playlistSelfCnt = _GetJsonPlaylistCount(_entries[0]);
			}
			note += "<Playlist";
			if (playlistSelfCnt > 0) note += ": " + playlistSelfCnt;
			note += ">";
			if (!_isGeneric(extractor)) note += " @" + extractor;
		}
		if (_CheckStartTime(startTimeLocal, path)) return "";
		
		MetaData["author"] = note;
		MetaData["duration"] = "";
		outUrl = thumb;
		if (isYoutube || _WebsitePlaylistMode(inUrl) > 0)
		{
			_PotPlayerAddList(inUrl, 0);
		}
		if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] This URL is for a playlist.\r\n");
		return outUrl;
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
		title = _ReviseDesc(title);
	}
	
	string duration = _GetJsonValueString(root, "duration_string");
	if (duration.empty())
	{
		int secDuration = _GetJsonValueInt(root, "duration");
		if (secDuration > 0)
		{
			duration = "0:" + secDuration;
			// Convert to format "hh:mm:ss" with adding "0:" to the top.
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
		if (sch.findI(extractor, "facebook") >= 0)	// facebook
		{
			int pos = title.findLast(" | ");
			if (pos >= 0) author = title.substr(pos + 3);
		}
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
	if (!author.empty()) author = _ReviseDesc(author);
	
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
	desc = _ReviseDesc(desc);
	
	string baseName = _GetJsonValueString(root, "webpage_url_basename");
	string ext2 = HostGetExtension(baseName);	// include the top dot
	
	if (_CheckStartTime(startTimeLocal, path)) return "";
	
	string title2;	// substantial title
	{
		if (!title.empty() && baseName == title + ext2) {}
			// MetaData["title"] is empty if yt-dlp cannot get a substantial title
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
				title2 = title2.substr(author.size() + 3);
			}
		}
		if (sch.findI(extractor, "facebook") >= 0)	// facebook
		{
			// Remove the count of playback/reactions/share in the title top.
			int pos = title2.findFirst(" | ");
			if (pos >= 0) title2 = title2.substr(pos + 3);
			
			// Remove the uploader name
			pos = title2.findLast(" | ");
			if (pos >= 0) title2 = title2.Left(pos);
		}
		if (!desc.empty() && sch.isCutoffDesc(title2, desc))
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
			string _date = sch.getRegExp(title2.substr(author.size()), "(?i)^ \\(live\\) (\\d{4}\\-\\d{2}\\-\\d{2}.*)$");
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
		title2 = _CutoffDesc(title2);
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
//HostMessageBox("------ title2 ------\n" + title2 + "\n\n\n" + "------ desc ------\n" + desc, "", 2, 0);
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
	
	JsonValue jFormats = root["formats"];
	if (!jFormats.isArray() || jFormats.size() == 0)
	{
		// Do not treat it as an error.
		// For getting uploader(website) or thumbnail or upload date.
		if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] No formats data...\r\n");
	}
	
	if (_CheckStartTime(startTimeLocal, path)) return "";
	
	uint vaCount = 0;
	uint vCount = 0;
	uint aCount = 0;
	for (int i = jFormats.size() - 1; i >= 0 ; i--)
	{
		JsonValue jFormat = jFormats[i];
		
		string protocol = _GetJsonValueString(jFormat, "protocol");
		if (protocol.Left(4) != "http" && protocol.Left(4) != "m3u8")
		{
			continue;
		}
		
		int qualityIdx = _GetJsonValueInt(jFormat, "quality");
		
		string fmtUrl = _GetJsonValueString(jFormat, "url");
//HostPrintUTF8("fmtUrl: " + fmtUrl);
		if (fmtUrl.empty()) continue;
		
		if (@QualityList !is null)
		{
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
				if (qualityIdx == -1 && !isLive) continue;	// audio for non-merged on youtube
				if (aExt != "none" || acodec != "none")
				{
					va = "a";	// audio only
				}
				else
				{
					continue;
				}
			}
			
			int height = _GetJsonValueInt(jFormat, "height");
			int width = _GetJsonValueInt(jFormat, "width");
			float vbr = _GetJsonValueFloat(jFormat, "vbr");
			float tbr = _GetJsonValueFloat(jFormat, "tbr");
			float abr = _GetJsonValueFloat(jFormat, "abr");
			
			if (cfg.getInt("FORMAT", "reduce_low_quality") == 1)
			{
				int _count = (va == "v" ? vCount : va == "va" ? vaCount : 0);
				if (_count > 0)
				{
					int _width = (width < height ? height : width);
					if (_width > 0)
					{
						if (_width < 640 && _count >= 3) continue;
						if (_width < 850 && _count >= 6) continue;
						if (_width < 1280 && _count >= 10) continue;
					}
				}
				else if (va == "a" && abr > 0)
				{
					if (abr < 100 && aCount >= 2) continue;
				}
			}
			
			string bitrate;
			if (tbr > 0) bitrate = HostFormatBitrate(int(tbr * 1000));
			else if (vbr > 0 && abr > 0) bitrate = HostFormatBitrate(int((abr + vbr) * 1000));
			else if (vbr > 0) bitrate = HostFormatBitrate(int(vbr * 1000));
			else if (abr > 0) bitrate = HostFormatBitrate(int(abr * 1000));
			
			float fps = _GetJsonValueFloat(jFormat, "fps");
			
			string dynamicRange = _GetJsonValueString(jFormat, "dynamic_range");
			if (dynamicRange.empty() && va != "a") dynamicRange = "SDR";
			
			int itag = _GetJsonValueInt(jFormat, "format_id");
			
			string resolution = "";
			if (width > 0 && height > 0)
			{
				resolution = formatInt(width) + "×" + formatInt(height);
			}
			else
			{
				resolution = _GetJsonValueString(jFormat, "resolution");
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
				
				language = _GetJsonValueString(jFormat, "language");
				if (!language.empty() && language != "und")	// und = undetermined
				{
					note = _GetJsonValueString(jFormat, "format_note");
					note = sch.omitDecimal(note, ",");
					if(_CheckLangageName(note))
					{
						format += note + ", ";
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
				quality = _GetJsonValueString(jFormat, "format");
				if (quality.empty())
				{
					quality = _GetJsonValueString(jFormat, "format_id");
				}
			}
			
			// for Tiktok
			string cookies = _GetJsonValueString(jFormat, "cookies");
			
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
				if (sch.findI(dynamicRange, "SDR") < 0) dic["isHDR"] = true;
			}
			if (!cookies.empty())
			{
//HostPrintUTF8("cookies: " + cookies);
				dic["cookies"] = cookies;
			}
			
			while (HostExistITag(itag)) itag++;
			HostSetITag(itag);
			dic["itag"] = itag;
			
			if (cfg.getInt("FORMAT", "remove_duplicate_quality") == 1)
			{
				if (_IsSameQuality(dic, QualityList)) continue;
			}
			
//HostPrintUTF8("itag: " + itag + "\tquality: " + quality + "\tformat: " + format + "\tfps: " + fps);
			
			if (va == "v") vCount++;
			else if (va == "a") aCount++;
			else if (va == "va") vaCount++;
			
			QualityList.insertLast(dic);
		}
	}
	if (_CheckStartTime(startTimeLocal, path)) return "";
	
	if (@QualityList !is null)
	{
		array<dictionary> dicsSub;
		JsonValue jSubtitles = root["requested_subtitles"];
		if (jSubtitles.isObject())
		{
			array<string> subs = jSubtitles.getKeys();
			for (uint i = 0; i < subs.size(); i++)
			{
				string langCode = subs[i];
				JsonValue jSub = jSubtitles[langCode];
				if (jSub.isObject())
				{
					string subUrl = _GetJsonValueString(jSub, "url");
					if (!subUrl.empty())
					{
						{
							// .vtt.m3u8 -> .vtt
							int pos = sch.findRegExp(subUrl, "(?i)\\.vtt(\\.m3u8)(?:\\?.*)?$");
							if (pos > 0) subUrl.erase(pos, 5);
						}
						if (isYoutube)
						{
							// Remove unstable position data on youtube.
							// &fmt=vtt -> &fmt=srt
							int pos = sch.findRegExp(subUrl, "(?i)&fmt=(vtt)\\b");
							if (pos > 0)
							{
								subUrl.erase(pos, 3);
								subUrl.insert(pos, "srt");
							}
						}
					}
					string subData = _GetJsonValueString(jSub, "data");
					
					if (!subUrl.empty() || !subData.empty())
					{
						dictionary dic;
						dic["langCode"] = langCode;
						if (!subUrl.empty()) dic["url"] = subUrl;
						if (!subData.empty()) dic["data"] = subData;
//HostPrintUTF8("sub lang: " + langCode + "\turl: " + subUrl);
						string subName = _GetJsonValueString(jSub, "name");
						if (!subName.empty()) dic["name"] = subName;
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
		jSubtitles = root["automatic_captions"];
		if (jSubtitles.isObject())
		{
			array<string> subs = jSubtitles.getKeys();
			for (uint i = 0; i < subs.size(); i++)
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
									if (sch.findI(subExt, "srt") >= 0)	// or vtt, srv
									{
										string subUrl = _GetJsonValueString(jSsub, "url");
										if (!subUrl.empty())
										{
											dictionary dic;
											dic["kind"] = "asr";
											dic["langCode"] = langCode;
											dic["url"] = subUrl;
											string subName = _GetJsonValueString(jSsub, "name");
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
		JsonValue jChapters = root["chapters"];
		if (jChapters.isArray())
		{
			for(int i = 0; i < jChapters.size(); i++)
			{
				JsonValue jChapter = jChapters[i];
				if (jChapter.isObject())
				{
					string cptTitle = _GetJsonValueString(jChapter, "title");
					if (!cptTitle.empty())
					{
						dictionary dic;
						dic["title"] = cptTitle;
						float startTime = _GetJsonValueFloat(jChapter, "start_time");
						if (isLive)
						{
							// For Twitch with --live-from-start
							// Generally PotPlayer cannot reflect chapter positions on live stream.
							float secDuration = _GetJsonValueFloat(root, "duration");
							if (secDuration > 0)
							{
								// Negative number means past time.
								startTime -= secDuration;
							}
							else
							{
								startTime = 0;
							}
						}
						dic["time"] = formatInt(int(startTime * 1000));	// milli-second;
						dicsChapter.insertLast(dic);
					}
				}
			}
		}
		if (dicsChapter.size() > 0) MetaData["chapter"] = dicsChapter;
	}
	if (_CheckStartTime(startTimeLocal, path)) return "";
	
	if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Parsing complete (" + extractor + "). - " + ytd.qt(inUrl) +"\r\n");
	
	return outUrl;
}


