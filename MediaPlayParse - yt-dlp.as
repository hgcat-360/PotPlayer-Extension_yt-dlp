/*************************************************************
  Parse Streaming with yt-dlp
**************************************************************
  Extension script for PotPlayer 250226 or later versions
  Placed in \PotPlayer\Extension\Media\PlayParse\
*************************************************************/

string SCRIPT_VERSION = "250816";


string YTDLP_EXE = "Module\\yt-dlp.exe";
	//yt-dlp executable file; relative path to HostGetExecuteFolder(); (required)

string SCRIPT_CONFIG_DEFAULT = "yt-dlp_default.ini";
	//default configuration file; placed in HostGetScriptFolder(); (required)

string SCRIPT_CONFIG_CUSTOM = "Extension\\Media\\PlayParse\\yt-dlp.ini";
	//configuration file; relative path to HostGetConfigFolder()
	//created automatically by this script

string RADIO_IMAGE_1 = "yt-dlp_radio1.jpg";
string RADIO_IMAGE_2 = "yt-dlp_radio2.jpg";
	//radio image files; placed in HostGetScriptFolder()


class FileConfig
{
	string codeDef;	//character code of the default config file
	
	bool showDialog = false;
	bool errorDefault = false;
	bool errorSave = false;
	
	string BOM_UTF8 = "\xEF\xBB\xBF";
	string BOM_UTF16LE = "\xFF\xFE";
	//string BOM_UTF16BE = "\xFE\xFF";
	
	string _changeEolWin(string str)
	{
		//LF -> CRLF
		//Not available if EOL is only CR
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
			//consider codes only as utf8 or utf16le
		}
		return str;
	}
	
	string readFileDef()
	{
		string str;
		string msg = "";
		string path = HostGetScriptFolder() + SCRIPT_CONFIG_DEFAULT;
		uintptr fp = HostFileOpen(path);
		if (fp > 0)
		{
			str = HostFileRead(fp, HostFileLength(fp));
			HostFileClose(fp);
			
			if (str.empty())
			{
				msg =
				"This default config file is empty.\r\n"
				"Please use a proper file.\r\n\r\n";
			}
			else if (str.find("\n") < 0)
			{
				msg =
				"This default config file is not available.\r\n"
				"Please use a proper file.\r\n"
				"(Supported EOL code: CRLF or LF)\r\n\r\n";
			}
			else
			{
				str = _changeToUtf8Basic(str, codeDef);
				if (!HostRegExpParse(str, "^\\w+=", {}))
				{
					msg =
					"The script cannot read this default config file.\r\n"
					"Please use a proper file.\r\n"
					"(Supported character code: UTF8(bom) or UTF16 LE)\r\n\r\n";
					codeDef = "";
				}
			}
		}
		else
		{
			msg =
			"The following default config file was not found.\r\n"
			"Please place it in the same folder as the script file.\r\n\r\n";
			codeDef = "";
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
		//this folder is relative to HostGetConfigFolder()
		//it does not include a file name
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
		//it includes a file name
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
	array<string> sectionNamesDef;	//default section names
	array<string> sectionNamesCst;	//customize section order
	dictionary keyNames;	//{section, {key}} dictionary with array
	
	dictionary kdsDef;	//default data
	dictionary kdsCst;	//customized data
		// {section, {key, KeyData}} dictionary with dictionary
	
	//specific properties of each script
	int csl = 0;	//console out
	string baseLang;
	
	string _escapeQuote(string str)
	{
		//do not use Trim("\"")
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
	
	int _getBlankLine(string str, int pos)
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
	
	string _addBlankLast(string str)
	{
		int pos = str.findLastNotOf("\r\n", str.size());
		if (pos >= 0) pos += 1; else pos = 0;
		str = str.Left(pos);
		str += "\r\n\r\n";
		return str;
	}
	
	int _getSectionSepaNext(string str, int from)
	{
		int pos = str.find("\n[", from);
		if (pos >= 0) pos += 1; else pos = _getBlankLine(str, -1);
		return pos;
	}
	
	string _getSectionNext(string str, int &inout pos)
	{
		if (str.empty() || pos < 0 || uint(pos) >= str.size()) {pos = -1; return "";}
		
		string section = "";
		array<dictionary> match;
		pos = sch.regExpParse(str, "^\\[([^\n\r\t\\]]*?)\\]", match, pos);
		if (pos >= 0) match[1].get("first", section);
		return section;
	}
	
	string _getSectionAreaNext(string str, string &out section, int &inout pos)
	{
		string sectArea;
		section = _getSectionNext(str, pos);
		if (pos >= 0)
		{
			int pos2 = _getSectionSepaNext(str, pos);
			sectArea = str.substr(pos, pos2 - pos);
		}
		return sectArea;
	}
	
	string _getKeyNext(string str, int &inout pos)
	{
		if (str.empty() || pos < 0 || uint(pos) >= str.size()) {pos = -1; return "";}
		
		string key = "";
		int sepa = _getSectionSepaNext(str, pos);
		array<dictionary> match;
		pos = sch.regExpParse(str, "^(?://)?(#?\\w+)=", match, pos);
		if (pos >= 0 && pos <= sepa)
		{
			match[1].get("first", key);
		}
		return key;
	}
	
	string _getKeyAreaNext(string str, string &out key, int &inout pos)
	{
		string keyArea;
		key = _getKeyNext(str, pos);
		if (pos >= 0)
		{
			int pos2 = _getBlankLine(str, pos);
			int sepa = _getSectionSepaNext(str, pos);
			if (pos2 > sepa) pos2 = sepa;
			keyArea = str.substr(pos, pos2 - pos);
		}
		return keyArea;
	}
	
	int _searchKeyTop(string sectArea, string key)
	{
		array<dictionary> match;
		int pos = sch.regExpParse(sectArea, "(?i)^[^\t\r\n]*\\b" + key + " *=", match, 0);
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
		int sepa = _getSectionSepaNext(str, pos);
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
			"(?i)^[^\t\r\n]*\\b" + kd.key + " *=",	//comment out
			"(?i)^ *" + kd.key + " *= *",	//empty value
			"(?i)^ *" + kd.key + " *= *(\\S[^\t\r\n]*)"	//specified value
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
				match[0].get("first", s1);
				if (state > 0)
				{
					str.erase(keyTop, s1.size());
					str.insert(keyTop, kd.key + "=");
					valueTop = keyTop + kd.key.size() + 1;
				}
				if (state == 2)
				{
					match[1].get("first", value);
					int pos2;
					match[1].get("second", pos2);
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
			if (key.Left(1) == "#") key = key.substr(1);	//hidden key
			KeyData kd(section, key);
			int pos = _searchKeyTop(sectArea, key);
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
			if (key.Left(1) == "#") key = key.substr(1);	//hidden key
			if (_kds.get(key, kd))
			{
				if (kd.areaTop >= 0)
				{
					int idx = tops.find(kd.areaTop);
					if (idx < 0) continue;
					idx++;
					uint pos2 = uint(idx) < tops.size() ? tops[idx] : sectArea.size();
					int blnk = _getBlankLine(sectArea, kd.areaTop);
					if (pos2 > uint(blnk)) pos2 = blnk;
					string keyArea = sectArea.substr(kd.areaTop, pos2 - kd.areaTop);
					keyArea = _addBlankLast(keyArea);
					kd.areaStr = keyArea;
					kd.areaTop = -1;
				}
				else
				{
					//Add missing keys
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
				sectArea = str.Left(_getSectionSepaNext(str, 0));
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
						int idx = sch.findi(sections, section);
						if (idx >= 0)
						{
							section = sections[idx];	//fix difference in case
							sections.removeAt(idx);
							sectionNamesCst.insertLast(section);
							__loadCst(sectArea, section);
						}
					}
					pos += sectArea.size();
				}
			} while (pos > pos0);
			
			if (sections.size() > 0)
			{
				//Add the missing section
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
	}
	
	string _getCfgStr(bool isDef)
	{
		dictionary kds;
		array<string> sections;
		if (isDef) {kds = kdsDef; sections = sectionNamesDef;}
		else {kds = kdsCst; sections = sectionNamesCst;}
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
					if (key.Left(1) == "#")	//hidden key
					{
						if ( isDef) continue;
						else key = key.substr(1);
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
	
	string _getCfgStrDef()
	{
		return _getCfgStr(true);
	}
	
	string _getCfgStrCst()
	{
		return _getCfgStr(false);
	}
	
	string _getCfgStr(bool isDef, string section)
	{
		dictionary kds;
		array<string> sections;
		if (isDef) {kds = kdsDef; sections = sectionNamesDef;}
		else {kds = kdsCst; sections = sectionNamesCst;}
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
				if (key.Left(1) == "#")	//hidden key
				{
					if ( isDef) continue;
					else key = key.substr(1);
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
	
	string _getCfgStrDef(string section)
	{
		return _getCfgStr(true, section);
	}
	
	string _getCfgStrCst(string section)
	{
		return _getCfgStr(false, section);
	}
	
	string _getCfgStr(bool isDef, string section, string key)
	{
		if (key.Left(1) == "#" && !isDef) key = key.substr(1);	//hidden key
		
		dictionary kds;
		array<string> sections;
		if (isDef)
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
		}
		return str;
	}
	
	string _getCfgStrDef(string section, string key)
	{
		return _getCfgStr(true, section, key);
	}
	
	string _getCfgStrCst(string section, string key)
	{
		return _getCfgStr(false, section, key);
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
			//specific processes of each script
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
			//specific properties of each script
			csl = getInt("MAINTENANCE", "console_out");
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
		//useDef
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
					kd.areaStr = _getCfgStrDef(section, key);
					if (kd.areaStr.empty())
					{
						kd.areaStr = _getCfgStrDef(section, "#" + key);
						if (kd.areaStr.Left(1) == "#") kd.areaStr = kd.areaStr.substr(1);
					}
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
	
	int findi(string str, string search)
	{
		//case-insensitive search
		str.MakeLower();
		search.MakeLower();
		return str.find(search);
	}
	
	int findi(array<string> arr, string search)
	{
		//case-insensitive search in array
		for (uint i = 0; i < arr.size(); i++)
		{
			if (arr[i].MakeLower() == search.MakeLower()) return i;
		}
		return -1;
	}
	
	
	string _regLower(string reg)
	{
		//avoid regular expressions
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
				//just after "\\"
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
	
	int regExpParse(string str, string reg, array<dictionary> &inout match, int posFrom)
	{
		//modify HostRegExpParse
		if (str.empty() || reg.empty() || match is null) return -1;
		if (posFrom < 0 || uint(posFrom) >= str.size()) return -1;
		bool caseInsens = false;
		string strOrig = str;
		if (reg.Left(4) == "(?i)")
		{
			//case-insensitive is not available to HostRegExpParse
			caseInsens = true;
			reg = reg.substr(4);
			str.MakeLower();
			reg = _regLower(reg);
		}
		
		array<dictionary> _match;
		string _str = str.substr(posFrom);
		if (HostRegExpParse(_str, reg, _match))
		{
			for (uint i = 0; i < _match.size(); i++)
			{
				string s1, s2;
				_match[i].get("first", s1);
				_match[i].get("second", s2);
				int pos = _str.size() - s2.size() - s1.size();
				pos = posFrom + pos;
				{
					dictionary dic;
					if (!caseInsens)
					{
						dic.set("first", s1);
					}
					else
					{
						dic.set("first", strOrig.substr(pos, s1.size()));
					}
					dic.set("second", pos);
					match.insertLast(dic);
				}
			}
			int pos0;
			match[0].get("second", pos0);
			return pos0;
		}
		return -1;
	}
	
	int getEol(string str, int pos)
	{
		//does not include EOL characters at the end
		if (pos >= 0) pos = str.find("\n", pos);
		if (pos < 0) pos = str.size();
		pos = str.findLastNotOf("\r\n", pos);
		if (pos >= 0) pos += 1; else pos = 0;
		return pos;
	}
	
	int getLineTop(string str, int pos)
	{
		if (pos < 0) pos = str.size();
		pos = str.findLastNotOf("\r\n", pos);
		if (pos < 0) pos = 0;
		pos = str.findLastOf("\r\n", pos);
		if (pos >= 0) pos += 1; else pos = 0;
		return pos;
	}
	
	int getLine(string str, int pos, string &out line)
	{
		if (pos < 0) return -1;
		int pos1 = str.findFirstNotOf("\r\n", pos);
		if (pos1 < 0) return -1;
		int pos2 = getEol(str, pos1);
		line = str.substr(pos1, pos2 - pos1);
		return pos2;
	}
	
}


SCH sch;

//----------------------- END of class SCH -------------------------



class YTDLP
{
	string fileExe = HostGetExecuteFolder() + YTDLP_EXE;
	string version = "";
	array<string> errors = {"(OK)", "(NOT FOUND)", "(LOOKS_DUMMY)", "(CRITICAL ERROR!)"};
	int error = 0;
	string SCHEME = "dl//";
	
	string qt(string str)
	{
		//enclose in double quotes
		if (str.Right(1) == "\\")
		{
			//when enclosed as \"...\", escape the trailing back-slash character
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
			else if (verInfo.GetLegalCopyright().find("UNLICENSE") < 0 || verInfo.GetProductVersion().find("Python") < 0)
			{
				doubt = true;
			}
			else
			{
				version = verInfo.GetFileVersion();	//get version
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
					string msg = "You are using a newly added [yt-dlp.exe].\r\n\r\n";
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
						"current version: " + version + "\r\n\r\n"
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
		string msg = "Your copy of [yt-dlp.exe] behaved unexpectedly.\r\n";
		HostPrintUTF8("\r\n[yt-dlp] CRITICAL ERROR! " + msg);
		msg += "After confirming no problems, set [critical_error] to 0 in the config file and reload the script.";
		HostMessageBox(msg, "[yt-dlp] CRITICAL ERROR", 3, 2);
	}
	
	void updateVersion()
	{
		checkFile(false);
		if (error != 0) return;
		HostIncTimeOut(10000);
		string output = HostExecuteProgram(fileExe, " -U");
		if (output.find("Latest version:") < 0 && output.find("ERROR:") < 0)
		{
			HostPrintUTF8("[yt-dlp] ERROR! No data in output.\r\n");
			criticalError();
			return;
		}
		output = output.Left(sch.getEol(output, -1));
		HostMessageBox(output, "[yt-dlp] INFO: Update yt-dlp.exe", 2, 1);
		error = -1;
		checkFile(true);
	}
	
	bool _checkLogCommand(string log)
	{
		string errMsg = "\nyt-dlp.exe: error: ";
		int pos1 = sch.findi(log, errMsg);
		if (pos1 >= 0)
		{
			pos1 += errMsg.size();
			int pos2 = sch.getEol(log, pos1);
			string msg = log.substr(pos1, pos2 - pos1);
			if (sch.findi(msg, "unsupported browser specified for cookies") >= 0)
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
		if (log.find("[debug] Command-line config:") < 0)
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
			int pos2 = sch.getEol(log, pos1);
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
		array<dictionary> match;
		int pos = sch.regExpParse(log, "(?i)^error: could not ([^\r\n]+?) cookies? database", match, 0);
		if (pos >= 0)
		{
			string browser = cfg.getStr("COOKIE", "cookie_browser");
			if (!browser.empty())
			{
				string op = "";
				match[1].get("first", op);
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
				int pos2 = sch.getEol(log, pos);
				msg = log.substr(pos, pos2 - pos) + "\r\n";
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
		if (HostRegExpParse(log, "Error: [^\r\n]* not available from your location due to geo restriction", {}))
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
						if (log.find("Unable to write", pos1) == pos1)
						{
							msg +=
							"Unable to overwrite [yt-dlp.exe] here.\r\n"
							+ fileExe + "\r\n\r\n"
							"Replace it manually or try running PotPlayer with administrator privileges.\r\n\r\n";
						}
						else
						{
							int pos2 = sch.getEol(log, pos1);
							msg += log.substr(pos1, pos2 - pos1) + "\r\n\r\n";
						}
						msg += "The [update_ytdlp] setting will be reset.";
						HostMessageBox(msg, "[yt-dlp] ERROR: Auto update", 0, 0);
						cfg.setInt("MAINTENANCE", "update_ytdlp", 0);
						return -1;
					}
					else
					{
						int pos2 = sch.getEol(log, pos1);
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
		if (HostRegExpParse(log, "^ERROR: [^\r\n]* is (not currently live|offline)", {}))
		{
			string msg = "This channel is not currently live.\r\n\r\n" + url;
			HostMessageBox(msg, "[yt-dlp] INFO", 2, 0);
			return true;
		}
		return false;
	}
	
	bool _checkLiveFromStart(string log, string options)
	{
		if (HostRegExpParse(log, "^ERROR: [^\r\n]*there are no formats that can be downloaded from the start", {}))
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
		string strOut = "";
		_removeMetadata(log);
		int pos = 0;
		int pos0;
		string log0;
		do {
			pos0 = pos;
			array<dictionary> match;
			pos = sch.regExpParse(log, "(?i)(?:error|warning)", match, pos);
			if (pos >= 0)
			{
				pos = sch.getLineTop(log, pos);
				int pos2 = sch.getEol(log, pos);
				strOut += log.substr(pos, pos2 - pos) + "\r\n";
				pos = pos2;
			}
		} while (pos > pos0);
		
		return strOut;
	}
	
	bool _removeMetadata(string &inout log)
	{
		//remove the metadata area that cannot be used for judgment
		string reg = "(?i)(\\n\\[debug\\] ffmpeg command line:.+?)\\n(?:\\[|error:|warning:)";
		array<dictionary> match;
		int pos = sch.regExpParse(log, reg, match, 0);
		if (pos >= 0)
		{
			string s;
			match[1].get("first", s);
			log.erase(pos, s.size());
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
	
	array<array<string>> waitOutputs = {{}, {}, {}};
		//waitOutputs[idx] : {urls waiting outputs for}
		// idx  0: parse item  / 1: parse playlist  / 2: download
	
	bool retryLive = false;
	
	array<string> exec(string url, bool isPlaylist)
	{
		checkFile(true);
		if (error != 0) return {};
		
		if (cfg.csl > 0) HostOpenConsole();
		
		int woi;
		woi = waitOutputs[0].find(url);
		if (woi >= 0 )
		{
			waitOutputs[0].removeAt(woi);
			return {};
		}
		woi = waitOutputs[1].find(url);
		if (woi >= 0 )
		{
			//waitOutputs[1].removeAt(woi);
			//return {};
		}
		
		string options = "";
		bool isYoutube = _IsUrlSite(url, "youtube");
		string argYoutube = "youtube:lang=" + cfg.baseLang;
		
		if (!isPlaylist)	//a single video/audio
		{
			if (cfg.csl > 0) HostPrintUTF8("\r\n[yt-dlp] " + (retryLive ? "Retry " : "") + "Parsing... - " + qt(url) + "\r\n");
			
			options += " --no-playlist";
			options += " -I 1";
			options += " --all-subs";
			if (retryLive)
			{
				retryLive = false;
			}
			else if (isYoutube)
			{
				/*
				if (cfg.getInt("YOUTUBE", "youtube_live") == 2)
				{
					options += " --live-from-start";
				}
				*/
			}
			else
			{
				if (cfg.getInt("FORMAT", "live_as_vod") == 1)
				{
					options += " --live-from-start";	//for twitch
				}
			}
			
			string potoken;
			_addOptionsCookie(options, potoken);
			{
				string potokenSubs = cfg.getStr("YOUTUBE", "potoken_subs");
				if (!potokenSubs.empty())
				{
					if (!potoken.empty())
					{
						potoken += ",web.subs+" + potokenSubs;
					}
					else
					{
						potoken = "po_token=web.subs+" + potokenSubs;
					}
				}
			}
			if (!potoken.empty()) argYoutube += ";" + potoken;
		}
		else	//playlist
		{
			if (cfg.csl > 0) HostPrintUTF8( "\r\n[yt-dlp] Extracting playlist entries... - " + qt(url) + "\r\n");
			
			if (isYoutube)
			{
				//Do not use cookies while extracting playlist items exept for youtube.
				string potoken;
				_addOptionsCookie(options, potoken);
				if (!potoken.empty()) argYoutube += ";" + potoken;
				
				options += " --no-playlist";
			}
			
			options += " --flat-playlist";
				//Fastest and reliable for collecting urls in a playlist.
				//But collected items have no title or thumbnail except for some websites like youtube.
				//Missing properties (title/thumbnail/duration) are fetched by a subsequent function "_getPlaylistItem".
			
			options += " -R 0 --file-access-retries 0 --fragment-retries 0";
				//For playlist, detailed data is not necessary. (no effect??)
			
			HostIncTimeOut(30000);
		}
		
		if (isYoutube)
		{
			options += " --extractor-args " + qt(argYoutube);
		}
		
		_addOptionsNetwork(options);
		
		if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 1)
		{
			options += " -U";
		}
		
		options += " -j";	// "-j" must be in lower case
		
		options += " -v -- " + qt(url);
		
		int idx = isPlaylist ? 1 : 0;
		if (waitOutputs[idx].find(url) < 0)
		{
			if (waitOutputs[idx].size() > 9) waitOutputs[idx].removeAt(0);
			waitOutputs[idx].insertLast(url);
		}
		
		//execute
		string output = HostExecuteProgram(fileExe, options);
		
		woi = waitOutputs[idx].find(url);
		if (woi >= 0 ) waitOutputs[idx].removeAt(woi);
		
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
			retryLive = true;
			return exec(url, isPlaylist);
		}
		
		_checkLogUpdate(log);
		if (entries.size() == 0)
		{
			if (output.find("ERROR") >= 0)
			{
				if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Unsupported. - " + qt(url) + "\r\n");
			}
			else if (sch.findi(output, "downloading 0 items") >= 0)
			{
				if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] No entries in this playlist. - " + qt(url) + "\r\n");
			}
			else
			{
				HostPrintUTF8("[yt-dlp] ERROR! No data or info.\r\n");
				criticalError();
			}
		}
		
		return entries;
	}
	
	void _addOptionsCookie(string &inout options, string &inout potoken)
	{
		string cookieFile = cfg.getStr("COOKIE", "cookie_file");
		bool hasCookie = false;
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
			
			string potokenGvs = cfg.getStr("YOUTUBE", "potoken_gvs");
			if (!potokenGvs.empty())
			{
				potoken = "player-client=default,mweb;po_token=mweb.gvs+" + potokenGvs;
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
	}
	
	void _addOptionsNetwork(string &inout options)
	{
		options += " --retry-sleep exp=1:10";
		
		string proxy = cfg.getStr("NETWORK", "proxy");
		if (!proxy.empty()) options += " --proxy " + qt(proxy);
		
		int socketTimeout = cfg.getInt("NETWORK", "socket_timeout");
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
	
	bool getPlaylistItems(array<dictionary> &inout dicsEntry, string urlPlaylist)
	{
		if (dicsEntry.empty() || urlPlaylist.empty()) return false;
		
		bool existTitle = false;
		bool existThumbnail = false;
		bool existDuration = false;
		for (uint i = 0; i < dicsEntry.size(); i++)
		{
			string title;
			if (!existTitle && dicsEntry[i].get("title", title) && !title.empty())
			{
				existTitle = true;
			}
			
			string thumbnail;
			if (!existThumbnail && dicsEntry[i].get("thumbnail", thumbnail) && !thumbnail.empty())
			{
				existThumbnail = true;
			}
			
			string duration;
			if (!existDuration && dicsEntry[i].get("duration", duration) && !duration.empty())
			{
				existDuration = true;
			}
			
			if (existTitle && existThumbnail && existDuration) return false;
		}
		
		HostIncTimeOut(dicsEntry.size() * 5000);
		
		string options = "";
		
		string argYoutube = "youtube:lang=" + cfg.baseLang;
		string potoken;
		_addOptionsCookie(options, potoken);
		if (!potoken.empty()) argYoutube += ";" + potoken;
		options += " --extractor-args " + qt(argYoutube);
		
		_addOptionsNetwork(options);
		options += " --no-flat-playlist";
		options += " --ignore-no-formats-error";
		if (!existTitle) options += " -O title";
		if (!existThumbnail) options += " -O thumbnail";
		if (!existDuration) options += " -O duration_string";
		options += " --encoding \"utf8\"";	//required to prevent garbled text
		options += " -- " + urlPlaylist;
		
		if (waitOutputs[1].find(urlPlaylist) < 0)
		{
			if (waitOutputs[1].size() > 9) waitOutputs[1].removeAt(0);
			waitOutputs[1].insertLast(urlPlaylist);
		}
		string output = HostExecuteProgram(ytd.fileExe, options);
		int woi = waitOutputs[1].find(urlPlaylist);
		if (woi >= 0 ) waitOutputs[1].removeAt(woi);
		
		if (!output.empty())
		{
			int pos = 0;
			for (uint i = 0; i < dicsEntry.size(); i++)
			{
				if (!existTitle)
				{
					string title;
					pos = sch.getLine(output, pos, title);
					if (pos < 0) break;
					if (title != "NA") dicsEntry[i].set("title", title);
				}
				if (!existThumbnail)
				{
					string thumbnail;
					pos = sch.getLine(output, pos, thumbnail);
					if (pos < 0) break;
					if (thumbnail != "NA") dicsEntry[i].set("thumbnail", thumbnail);
				}
				if (!existDuration)
				{
					string duration;
					pos = sch.getLine(output, pos, duration);
					if (pos < 0) break;
					if (duration != "NA") dicsEntry[i].set("duration", duration);
				}
			}
			return true;
		}
		return false;
	}
	
};

YTDLP ytd;

//---------------------- END of class YTDLP ------------------------



void OnInitialize()
{
	//called when loading script at first
	if (SCRIPT_VERSION.Right(1) == "#") HostOpenConsole();	//debug version
	cfg.loadFile();
	ytd.checkFile(false);
}


string GetTitle()
{
	//called when loading script and closing config panel with ok button
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
	//called when opening config panel
	fc.showDialog = true;
	cfg.loadFile();
	return SCRIPT_CONFIG_CUSTOM;
}


void ApplyConfigFile()
{
	//called when closing config panel with ok button
	if (!cfg.loadFile())
	{
		string msg = "The script cannot apply the configuration.\r\n";
		HostMessageBox(msg, "[yt-dlp] ERROR: Default config file", 0, 0);
	}
}


string GetDesc()
{
	//called when opening info panel
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
			"| Your [yt-dlp.exe] behaved unexpectedly.\r\n"
			"| After confirming no issues, reset [critical_error]\r\n"
			"| in the config file and reload the script.\r\n";
			break;
	}
	return info;
}


bool _IsUrlSite(string url, string website)
{
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
	else if (website.find(".") >= 0)	//if not ".com"
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


string _GetUrlExtension(string url)
{
	url.MakeLower();
	string ext = HostRegExpParse(url, "^https?://[^\\?#]+/[^\\/?#]+\\.(\\w+)(?:[?#].+)?$");
	return ext;
}


bool _CheckExt(string ext, int kind)
{
	if (ext.empty()) return false;
	if (ext.Left(1) == ".") ext = ext.substr(1);
	ext.MakeLower();
	
	array<string> exts;
	{
		if (kind & 0x1 > 0)	//image
		{
			array<string> extsImage = {"jpg", "jpeg", "png", "gif", "webp"};
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
	}
	
	if (exts.find(ext) >= 0) return true;
	return false;
}


string _reviseUrl(string url)
{
	if (url.Left(1) == "<")
	{
		//remove the time range if exists
		int pos = url.find(">", 0);
		if (pos >= 0) url = url.substr(pos + 1);
	}
	
	if (url.Left(ytd.SCHEME.size()) == ytd.SCHEME)
	{
		url = url.substr(ytd.SCHEME.size());
	}
	
	return url;
}


bool _PlayitemCheck(string &in url)
{
	if (ytd.error == 3 || cfg.getInt("SWITCH", "stop") == 1) return false;
	
	if (!HostRegExpParse(url, "^https?://", {})) return false;
	
	if (HostRegExpParse(url, "//192\\.168\\.\\d+\\.\\d+\\b", {})) return false;
		//Exclude LAN
	
	if (_IsUrlSite(url, "kakao")) return false;
		//Exclude KakaoTV
	
	string ext = _GetUrlExtension(url);
	if (!ext.empty())	//hot-link to a web file
	{
		int kind = 0x0;
		if (cfg.getInt("TARGET", "direct_media_file") < 1) kind |= 0x111;	//Exclude media files
		if (cfg.getInt("TARGET", "direct_playlist_file") < 1) kind |= 0x1000;	//Exclude playlist files
		kind |= 0x110000;	//Exclude compressed/subtitles files
		if (_CheckExt(ext, kind)) return false;
	}
	
	return true;
}

bool PlayitemCheck(const string &in path)
{
	string url = _reviseUrl(path);
	url.MakeLower();
	
	//called when an item is being opened after PlaylistCheck or PlaylistParse
	if (_IsUrlSite(url, "youtube"))
	{
		int enableYoutube = cfg.getInt("YOUTUBE", "enable_youtube");
		if (enableYoutube != 1 && enableYoutube != 2) return false;
		//Exclude youtube according to the setting
	}
	
	return _PlayitemCheck(url);
}

string _OmitStr(string str, string search, uint allowDigit = 0)
{
	int pos = str.find(search);
	if (pos < 0) return str;
	string str1 = str.substr(pos + search.size());
	if (str1.size() > allowDigit)
	{
		str = str.Left(pos);
	}
	return str;
}


string _FormatDate(string date)
{
	if (date.size() != 8) return date;
	string dateOut = HostRegExpParse(date, "^(\\d+)$");
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
		if (__IsSameQuality(dic, dics[i])) return true;
	}
	return false;
}


bool _CheckLangageName(string note)
{
	//return true if note is possible to be a language name
	if (!note.empty())
	{
		array<string> _qualities = {
			"low", "medium", "high", "Default"
		};
		if (_qualities.find(note) < 0)
		{
			if (!HostRegExpParse(note, "\\w{20}", {}))
			{
				if (sch.regExpParse(note, "(?i)\\b(?:dash|hls)\\b", {}, 0) < 0)
				{
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


string PlayitemParse(const string &in path, dictionary &MetaData, array<dictionary> &QualityList)
{
	//called after PlayitemCheck if it returns true
	
	string inUrl = _reviseUrl(path);
	array<string> entries = ytd.exec(inUrl, false);
	if (entries.size() == 0) return "";
	
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
	bool isYoutube = _IsUrlSite(inUrl, "youtube");
	
	string webUrl = _GetJsonValueString(root, "webpage_url");
	if (webUrl.empty())
	{
		HostPrintUTF8("[yt-dlp] ERROR! No webpage URL.\r\n");
		ytd.criticalError(); return "";
	}
	
	int playlistIdx = _GetJsonValueInt(root, "playlist_index");
	if (playlistIdx > 0 && inUrl != webUrl)
	{
		//Exclude playlist url
		if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] ERROR! This URL is for a playlist. You need to fetch the URL of each entry in it. - " + ytd.qt(inUrl) +"\r\n");
		return "";
	}
	bool isLive = _GetJsonValueBool(root, "is_live");
	if (isLive && cfg.getInt("YOUTUBE", "youtube_live") != 1 && isYoutube)
	{
		if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] YouTube Live was passed through according to the \"youtube_live\" setting. - " + ytd.qt(inUrl) +"\r\n");
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
				if (cfg.getInt("FORMAT", "more_detailed_title") == 1)
				{
					string alt_title = _GetJsonValueString(root, "alt_title");
					if (!alt_title.empty())
					{
						if (alt_title.find(title) >= 0)
						{
							title = alt_title;
						}
					}
				}
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
		if (isAudioExt && cfg.getInt("FORMAT", "radio_thumbnail") == 1)
		{
			thumbnail = _GetRadioThumbnail(isDirect);
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
	
	JsonValue jFormats = root["formats"];
	if (!jFormats.isArray() || jFormats.size() == 0)
	{
		//Do not treat it as an error.
		//For getting uploader(website) or thumbnail or upload date.
		if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] No formats data...\r\n");
	}
	
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
		if (urlOut.empty()) urlOut = fmtUrl;
		
		if (@QualityList !is null)
		{
			string fmtExt = _GetJsonValueString(jFormat, "ext");
			string vExt = _GetJsonValueString(jFormat, "video_ext");
			string aExt = _GetJsonValueString(jFormat, "audio_ext");
			if (fmtExt.empty() || vExt.empty() || aExt.empty()) continue;
			
			string vcodec = _GetJsonValueString(jFormat, "vcodec");
			vcodec = _OmitStr(vcodec, ".", 2);
			
			string acodec = _GetJsonValueString(jFormat, "acodec");
			acodec = _OmitStr(acodec, ".", 2);
			
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
				if (qualityIdx == -1 && !isLive) continue;	//audio for non-merged in youtube
				if (aExt != "none" || acodec != "none")
				{
					va = "a";	//audio only
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
				if (!language.empty() && language != "und")	//und = undetermined
				{
					note = _GetJsonValueString(jFormat, "format_note");
					note = _OmitStr(note, ",");
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
				quality = _GetJsonValueString(jFormat, "format_id");
				if (quality.empty())
				{
					quality = _GetJsonValueString(jFormat, "format");
					quality = _OmitStr(quality, " ");
				}
			}
			
			//for Tiktok
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
				if (dynamicRange.find("SDR") < 0) dic["isHDR"] = true;
			}
			if (!cookies.empty())
			{
//HostPrintUTF8("cookies: " + cookies);
				dic["cookies"] = cookies;
			}
			
//HostPrintUTF8("itag: " + itag + "\tquality: " + quality + "\tformat: " + format + "\tfps: " + fps);
			
			while (HostExistITag(itag)) itag++;
			HostSetITag(itag);
			dic["itag"] = itag;
			
			if (cfg.getInt("FORMAT", "remove_duplicated_quality") == 1)
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
							int pos = sch.regExpParse(subUrl, "\\.vtt\\.m3u8(\\?.*)?$", {}, 0);
							if (pos > 0) subUrl.erase(pos + 4, 5);
						}
						if (isYoutube)
						{
							//remove unstable position data in youtube
							// &fmt=vtt -> &fmt=srt
							int pos = sch.regExpParse(subUrl, "&fmt=vtt\\b", {}, 0);
							if (pos > 0)
							{
								subUrl.erase(pos + 5, 3);
								subUrl.insert(pos + 5, "srt");
							}
						}
						
						dictionary dic;
						dic["langCode"] = langCode;
						dic["url"] = subUrl;
//HostPrintUTF8("sub lang: " + langCode + "\turl: " + subUrl);
						string subName = _GetJsonValueString(jSub, "name");
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
									if (subExt.find("srt") >= 0)	//or vtt, srv
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
							//For Twitch with --live-from-start
							//Generally PotPlayer cannot reflect chapter positions on live stream.
							float secDuration = _GetJsonValueFloat(root, "duration");
							if (secDuration > 0)
							{
								//negative number means past time.
								startTime -= secDuration;
							}
							else
							{
								startTime = 0;
							}
						}
						dic["time"] = formatInt(int(startTime * 1000));	//milli-second;
						dicsChapter.insertLast(dic);
					}
				}
			}
		}
		if (dicsChapter.size() > 0) MetaData["chapter"] = dicsChapter;
	}
	if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Parsing completed by " + extractor + ". - " + ytd.qt(inUrl) +"\r\n");
	
	return urlOut;
}


bool PlaylistCheck(const string &in path)
{
	//called when a new item is being opend from a location other than potplayer's playlist
	//Some playlist extraction may freeze yt-dlp.
	
	
	string url = _reviseUrl(path);
	
	if (_IsUrlSite(url, "youtube"))
	{
		int enableYoutube = cfg.getInt("YOUTUBE", "enable_youtube");
		if (enableYoutube != 2 && enableYoutube != 3) return false;
	}
	else
	{
		if (cfg.getInt("TARGET", "website_playlist") < 1) return false;
	}
	
	if (!_PlayitemCheck(url)) return false;
	
	string ext = _GetUrlExtension(url);
	if (!ext.empty())
	{
		if (_CheckExt(ext, 0x110111)) return false;
		if (_CheckExt(ext, 0x1000))
		{
			if (cfg.getInt("TARGET", "direct_playlist_file") < 2) return false;
		}
	}
	
	return true;
}


dictionary _PlaylistParse(string json, bool forcePlaylist)
{
	dictionary dic;
	
	if (!json.empty())
	{
		JsonReader reader;
		JsonValue root;
		if (reader.parse(json, root) && root.isObject())
		{
			int playlistIdx = _GetJsonValueInt(root, "playlist_index");
			if (playlistIdx < 1)
			{
				if (forcePlaylist)
				{
					playlistIdx = 0;
				}
				else
				{
					return {};
				}
			}
			dic["playlistIdx"] = playlistIdx;
			
			string extractor = _GetJsonValueString(root, "extractor_key");
			if (extractor.empty()) extractor = _GetJsonValueString(root, "extractor");
			if (extractor.empty()) return {};
			dic["extractor"] = extractor;
			
			string url = _GetJsonValueString(root, "original_url");
			if (url.empty()) url = _GetJsonValueString(root, "webpage_url");
			if (url.empty()) return {};
			{
				//remove parameter added by yt-dlp
				int pos = url.find("#__youtubedl");
				if (pos > 0) url = url.Left(pos);
			}
			dic["url"] = url;
			
			string baseName = _GetJsonValueString(root, "webpage_url_basename");
			if (baseName.empty()) return {};
			dic["baseName"] = baseName;
			
			string title = _GetJsonValueString(root, "title");
			if (!title.empty()) dic["title"] = title;
			
			string thumbnail = _GetJsonValueString(root, "thumbnail");
			if (thumbnail.empty())
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
							thumbnail = _GetJsonValueString(jThumbmax, "url");
						}
					}
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
			
			string ext = _GetJsonValueString(root, "ext");
			if (!ext.empty()) dic["ext"] = ext;
			
			bool isDirect = _GetJsonValueBool(root, "direct");
			dic["isDirect"] = isDirect;
		}
	}
	
	return dic;
}


array<dictionary> PlaylistParse(const string &in path)
{
	//called after PlaylistCheck if it returns true
	
	string url = _reviseUrl(path);
	array<string> entries = ytd.exec(url, true);
	if (entries.size() == 0) return {};
	
	array<dictionary> dicsEntry;
	bool forcePlaylist = _IsUrlSite(url, "youtube");
		// For YouTube, this extension always treats a URL as a playlist
		// to prevent the built-in YouTube extension from changing the playlist state.
		// If a URL refers to both a video and a playlist
		// (e.g., https://www.youtube.com/watch?v=XXXXX&list=YYYYY),
		// this extension uses the --no-playlist option to ignore the playlist
		// and treats the URL as a playlist containing only that single video.
	
	int cnt = 0;
	for (uint i = 0; i < entries.size(); i++)
	{
		dictionary dic = _PlaylistParse(entries[i], forcePlaylist);
		if (!dic.empty())
		{
			string urlEntry;
			if (dic.get("url", urlEntry))
			{
				if (cfg.csl > 0)
				{
					if (cnt == 0)
					{
						string extractor;
						dic.get("extractor", extractor);
						HostPrintUTF8("Extractor: " + extractor);
					}
					int idx = int(dic["playlistIdx"]);
					HostPrintUTF8("URL " + idx + ": " + urlEntry);
				}
				
				dicsEntry.insertLast(dic);
				cnt++;
			}
		}
	}
	if (cfg.csl > 0) HostPrintUTF8("[yt-dlp] Playlist entries: " + cnt + "    - " + ytd.qt(url) +"\r\n");
	
	ytd.getPlaylistItems(dicsEntry, url);
	
	for (uint i = 0; i < dicsEntry.size(); i++)
	{
		string ext2;
		string baseName;
		if (dicsEntry[i].get("baseName", baseName))
		{
			ext2 = HostGetExtension(baseName);
		}
		
		string title;
		if (dicsEntry[i].get("title", title) && !title.empty())
		{
			if (!ext2.empty())
			{
				if (baseName == title + ext2)
				{
					dicsEntry[i].set("title", "");
					//consider title as empty if yt-dlp cannot get a substantial title.
					//Prevent potplayer from changing title in playlist.
				}
			}
		}
		
		string thumbnail;
		if (!dicsEntry[i].get("thumbnail", thumbnail))
		{
			if (cfg.getInt("FORMAT", "radio_thumbnail") == 1)
			{
				bool isAudioExt = false;
				if (!ext2.empty())
				{
					isAudioExt = _CheckExt(ext2, 0x100);
				}
				else
				{
					string ext;
					if (dicsEntry[i].get("ext", ext))
					{
						isAudioExt = _CheckExt(ext, 0x100);
					}
				}
				if (isAudioExt)
				{
					bool isDirect;
					dicsEntry[i].get("isDirect", isDirect);
					thumbnail = _GetRadioThumbnail(isDirect);
				}
			}
			if (thumbnail.empty())
			{
				string urlEntry;
				if (dicsEntry[i].get("url", urlEntry))
				{
					thumbnail = urlEntry;
				}
			}
			dicsEntry[i].set("thumbnail", thumbnail);
		}
		
		string duration;
		if (dicsEntry[i].get("duration", duration) && !duration.empty())
		{
			if (duration.find(":") < 0)
			{
				duration = "0:" + duration;
				dicsEntry[i].set("duration", duration);
			}
		}
	}
	
	return dicsEntry;
}


