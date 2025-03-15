/***************************************************
  Parse Streaming with yt-dlp
****************************************************
  Extension for PotPlayer 250226 or later versions
  Placed in \PotPlayer\Extension\Media\PlayParse\
***************************************************/

string SCRIPT_VERSION = "250315";

string YTDLP_EXE = "Module\\yt-dlp.exe";
	//yt-dlp executable file; relative path to HostGetExecuteFolder(); (required)

string SCRIPT_CONFIG_DEFAULT = "yt-dlp_default.ini";
	//default configuration file; placed in HostGetScriptFolder(); (required)

string SCRIPT_CONFIG = "Extension\\Media\\PlayParse\\yt-dlp.ini";
	//configuration file; relative path to HostGetConfigFolder()
	//created automatically by this script

string RADIO_IMAGE_1 = "yt-dlp_radio1.jpg";
string RADIO_IMAGE_2 = "yt-dlp_radio2.jpg";
	//radio image files; placed in HostGetScriptFolder()


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

class CFG
{
	string origCode;	//character code of the default config file
	array<string> sectionNamesDef;	//default section names
	array<string> sectionNamesCst;	//customize section order
	dictionary keyNames;	//{section, {key}} dictionary with array
	
	dictionary kdsDef;	//default data
	dictionary kdsCst;	//customized data
		// {section, {key, KeyData}} dictionary with dictionary
	
	int consoleOut = 0;
	string baseLang;
	
	bool isAlert = false;
	bool isDefaultError = false;
	bool isSaveError = false;
	
	string BOM_UTF8 = "\xEF\xBB\xBF";
	string BOM_UTF16LE = "\xFF\xFE";
	
	string _changeEolWin(string str)
	{
		int pos = 0;
		int pos0;
		do {
			pos0 = pos;
			pos = str.find("\n", pos);
			if (pos >= 0)
			{
				if (pos == 0)
				{
					str.insert(0, "\r");
					pos += 2;
				}
				else if (str.substr(pos - 1, 1) != "\r")
				{
					str.insert(pos - 1, "\r");
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
	
	string _readFileDefault()
	{
		string str;
		string path = HostGetScriptFolder() + SCRIPT_CONFIG_DEFAULT;
		uintptr fp = HostFileOpen(path);
		if (fp > 0)
		{
			isDefaultError = false;
			str = HostFileRead(fp, HostFileLength(fp));
			HostFileClose(fp);
			str = _changeToUtf8Basic(str, origCode);
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
			origCode = "utf8_bom";
		}
		return str;
	}
	
	uintptr _openFile(string &out str)
	{
		str = "";
		uintptr fp = _createFolderFile(SCRIPT_CONFIG);
		if (fp > 0)
		{
			str = HostFileRead(fp, HostFileLength(fp));
			string code;
			str = _changeToUtf8Basic(str, code);
			if (str.findFirstNotOf("\r\n") < 0) str = "";
		}
		return fp;
	}
	
	int _closeFile(uintptr fp, bool isWrite, string str)
	{
		int writeState = 0;
		if (fp > 0)
		{
			if (isWrite)
			{
				str = _changeFromUtf8Basic(str, origCode);
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
	
	int _searchBlankLine(string str, int pos)
	{
		if (pos == -1) pos = str.size();
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
		return -1;
	}
	
	int _getLastPos(string str)
	{
		//last position here is not always end of string
		int pos = -1;
		pos = _searchBlankLine(str, pos);
		if (pos < 0) pos = str.size();
		return pos;
	}
	
	int _addBlank(string &inout str, int &inout pos)
	{
		int add = 0;
		if (pos == -1) pos = str.size();
		pos = str.findLastNotOf("\r\n", pos);
		if (pos < 0) pos = 0;
		else pos += 1;
		if (uint(pos) == str.size() || str.substr(pos, 2) != "\r\n")
		{
			str.insert(pos, "\r\n\r\n");
			add = 4;
		}
		else if (str.substr(pos, 4) != "\r\n\r\n")
		{
			str.insert(pos, "\r\n");
			add = 2;
		}
		else
		{
			int pos2 = str.findFirstNotOf("\r\n", pos);
			if (pos2 < 0) pos2 = str.size();
			int pos1 = pos + 4;
			if (pos2 > pos1)
			{
				str.erase(pos1, pos2 - pos1);
				add = -(pos2 - pos1);
			}
		}
		pos += 4;
		return add;
	}
	
	int _addBlankLast(string &inout str)
	{
		int pos = -1;
		return _addBlank(str, pos);
	}
	
	int _getSectionSeparator(string str, int from)
	{
		int pos = str.find("\n[", from);
		if (pos >= 0) pos += 1; else pos = _getLastPos(str);
		return pos;
	}
	
	int _searchSectionTop(string str, string section)
	{
		int top = -1;
		if (!str.empty())
		{
			section = "[" + section + "]";
			if (str.Left(section.size()) == section) top = 0;
			else
			{
				top = str.find("\n" + section);
				if (top >= 0) top += 1;
			}
		}
		return top;
	}
	
	string _getSectionNext(string str, int &inout top)
	{
		string section = "";
		if (str.empty() || top < 0 || uint(top) >= str.size()) {top = -1; return "";}
		string _str = str.substr(top);
		array<dictionary> dicsMatch;
		if (HostRegExpParse(_str, "^\\[([^\n\r\t\\]]*?)\\]", dicsMatch))
		{
			dicsMatch[1].get("first", section);
			string s1, s2;
			dicsMatch[0].get("first", s1);
			dicsMatch[0].get("second", s2);
			int _top = _str.size() - s2.size() - s1.size();
			top += _top;
		}
		else
		{
			top = -1;
		}
		return section;
	}
	
	string _getSectionAreaNext(string str, string &out section, int &inout top)
	{
		string sectArea;
		section = _getSectionNext(str, top);
		if (top >= 0)
		{
			int end = _getSectionSeparator(str, top);
			sectArea = str.substr(top, end - top);
		}
		return sectArea;
	}
	
	string _getKeyNext(string str, int &inout top)
	{
		string key = "";
		if (str.empty() || top < 0 || uint(top) >= str.size()) {top = -1; return "";}
		string _str = str.substr(top);
		array<dictionary> dicsMatch;
		if (HostRegExpParse(_str, "^(#?\\w+)=", dicsMatch))
		{
			string s1, s2;
			dicsMatch[0].get("first", s1);
			dicsMatch[0].get("second", s2);
			int _top = _str.size() - s2.size() - s1.size();
			if (_top <= _getSectionSeparator(_str, 0))
			{
				dicsMatch[1].get("first", key);
				top += _top;
			}
			else top = -1;
		}
		else top = -1;
		
		return key;
	}
	
	string _getKeyAreaNext(string str, string &out key, int &inout top)
	{
		string keyArea;
		key = _getKeyNext(str, top);
		if (top >= 0)
		{
			int end = _searchBlankLine(str, top);
			int sepa = _getSectionSeparator(str, top);
			if (end > sepa) end = sepa;
			keyArea = str.substr(top, end - top);
		}
		return keyArea;
	}
	
	int _searchKeyTop(string sectArea, string key)
	{
		int top = -1;
		array<dictionary> dicsMatch;
		if (HostRegExpParse(sectArea, "^[^\t\r\n]*\\b" + key + " *=", dicsMatch))
		{
			string s1, s2;
			dicsMatch[0].get("first", s1);
			dicsMatch[0].get("second", s2);
			top = sectArea.size() - s2.size() - s1.size();
		}
		return top;
	}
	
	void _parseKeyDataDefault(KeyData &inout kd)
	{
		if (kd.section.empty() || kd.key.empty()) {kd.init(); return;}
		if (kd.areaStr.empty()) {kd.init(); return;}
		
		array<dictionary> dicsMatch;
		if (HostRegExpParse(kd.areaStr, "^" + kd.key + "=(\\S[^\t\r\n]*)", dicsMatch))
		{
			dicsMatch[1].get("first", kd.value);
		}
	}
	
	bool _loadDefault()
	{
		string str = _readFileDefault();
		if (str.empty()) return false;
		
		kdsDef = {};
		sectionNamesDef = {};
		keyNames = {};
		int top1 = 0;
		int _top1;
		do {
			_top1 = top1;
			string section;
			string sectArea = _getSectionAreaNext(str, section, top1);
			if (top1 >= 0 && !section.empty())
			{
				sectionNamesDef.insertLast(section);
				array<string> keys = {};
				dictionary _kds;
				int sepa = _getSectionSeparator(str, top1);
				int top2 = top1;
				int _top2;
				do {
					_top2 = top2;
					string key;
					string keyArea = _getKeyAreaNext(str, key, top2);
					if (top2 >= 0 && top2 < sepa)
					{
						keys.insertLast(key);
						KeyData kd(section, key);
						kd.areaStr = keyArea;
						_parseKeyDataDefault(kd);
						_kds.set(key, kd);
						top2 += keyArea.size();
					}
					else
					{
						break;
					}
				} while (top2 > _top2);
				keyNames.set(section, keys);
				kdsDef.set(section, _kds);
			}
			top1 += sectArea.size();
		} while (top1 > _top1);
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
			if (pos < 0) break;
		} while (pos > pos0);
		kd.areaStr = str;
	}
	
	void _parseKeyData(KeyData &inout kd)
	{
		array<string> patterns = {
			"^[^\t\r\n]*\\b" + kd.key + " *=",	//comment out
			"^ *" + kd.key + " *= *",	//empty value
			"^ *" + kd.key + " *= *(\\S[^\t\r\n]*)"	//specified value
		};
		
		if (kd.section.empty() || kd.key.empty()) {kd.init(); return;}
		string str = kd.areaStr;
		if (str.empty()) {kd.init(); return;}
		
		string value;
		int keyTop = -1;
		int valueTop = -1;
		int state;
		for (state = 2; state >= 0; state--)
		{
			array<dictionary> dicsMatch;
			if (HostRegExpParse(str, patterns[state], dicsMatch))
			{
				string s1, s2;
				dicsMatch[0].get("first", s1);
				dicsMatch[0].get("second", s2);
				keyTop = str.size() - s2.size() - s1.size();
				if (state > 0)
				{
					str.erase(keyTop, s1.size());
					str.insert(keyTop, kd.key + "=");
					valueTop = keyTop + kd.key.size() + 1;
				}
				if (state == 2)
				{
					dicsMatch[1].get("first", value);
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
					break;
				}
			}
		}
		
		kd.areaStr = str;
		kd.value = value;
		kd.state = state > 0 ? 1 : 0;
		kd.keyTop = keyTop;
		kd.valueTop = valueTop;
		
		_keyCommentOut(kd);
	}
	
	void _loadKeys(string sectArea, string section)
	{
		if (sectArea.Left(section.size() + 2) != "[" + section + "]") return;
		
		dictionary _kds;
		array<string> keys;
		if (!keyNames.get(section, keys)) return;
		
		array<uint> tops;
		for (uint i = 0; i < keys.size(); i++)
		{
			string key = keys[i];
			if (key.Left(1) == "#") key = key.substr(1);	//hidden key
			KeyData kd(section, key);
			int top = _searchKeyTop(sectArea, key);
			if (top >= 0)
			{
				kd.areaTop = top;
				tops.insertLast(top);
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
					uint end = uint(idx) < tops.size() ? tops[idx] : sectArea.size();
					int blk = _searchBlankLine(sectArea, kd.areaTop);
					if (blk >= 0 && uint(blk) < end) end = blk;
					string keyArea = sectArea.substr(kd.areaTop, end - kd.areaTop);
					_addBlankLast(keyArea);
					kd.areaStr = keyArea;
					kd.areaTop = -1;
				}
				else
				{
					//Add the missing key
					kd.areaStr = _getCfgStr(true, section, key);
				}
				_parseKeyData(kd);
				_kds.set(key, kd);
			}
		}
		kdsCst.set(section, _kds);
	}
	
	void _loadSections(string str)
	{
		kdsCst = {};
		sectionNamesCst = {};
		array<string> sections = sectionNamesDef;
		int top = 0;
		uint size0;
		do {
			size0 = str.size();
			string section;
			string sectArea = _getSectionAreaNext(str, section, top);
			if (top >= 0 && !sectArea.empty())
			{
				str.erase(top, sectArea.size());
				int idx = sections.find(section);
				if (idx >= 0)
				{
					sections.removeAt(idx);
					sectionNamesCst.insertLast(section);
					_loadKeys(sectArea, section);
				}
			}
			else
			{
				break;
			}
		} while (str.size() < size0);
		
		if (sections.size() > 0)
		{
			//Add the missing section
			for (uint i = 0; i < sections.size(); i++)
			{
				string sectAreaDef = _getCfgStr(true, sections[i]);
				if (!sectAreaDef.empty())
				{
					sectionNamesCst.insertLast(sections[i]);
					_loadKeys(sectAreaDef, sections[i]);
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
			str += "[" + section + "]\r\n\r\n";
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
	
	string _getCfgStr(bool isDef, string section)
	{
		dictionary kds;
		array<string> sections;
		if (isDef) {kds = kdsDef; sections = sectionNamesDef;}
		else {kds = kdsCst; sections = sectionNamesCst;}
		if (sections.size() == 0 || kds.size() == 0) return "";
		
		string str = "";
		str += "[" + section + "]\r\n\r\n";
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
	
	string _getCfgStr(bool isDef, string section, string key)
	{
		if (key.Left(1) == "#" && !isDef) key = key.substr(1);	//hidden key
		
		dictionary kds;
		array<string> sections;
		if (isDef) {kds = kdsDef; sections = sectionNamesDef;}
		else {kds = kdsCst; sections = sectionNamesCst;}
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
	
	void loadFile()
	{
		_loadDefault();
		
		string str0;
		uintptr fp = _openFile(str0);
		if (str0.empty()) str0 = _getCfgStr(true);
		
		_loadSections(str0);
		int critical_error = getInt("MAINTENANCE", "critical_error");
		if (critical_error == 0) deleteKey("MAINTENANCE", "critical_error");
		if (critical_error != 0 || ytd.error != 0) deleteKey("MAINTENANCE", "update_ytdlp");
		if (isSaveError) deleteKey("MAINTENANCE", "ytdlp_hash");
		
		string str = _getCfgStr(false);
		
		if (_closeFile(fp, str != str0, str) < 1)
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
		
		if (getStr("YOUTUBE", "base_lang").size() > 1) baseLang = getStr("YOUTUBE", "base_lang");
		else baseLang = HostIso639LangName();
		
		consoleOut = getInt("MAINTENANCE", "console_out");
	}
	
	int _saveFile()
	{
		string str0;
		uintptr fp = _openFile(str0);
		string str = _getCfgStr(false);
		return _closeFile(fp, str != str0, str);
	}
	
	bool deleteKey(string section, string key)
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
				_saveFile();
				return true;
			}
		}
		return false;
	}
	
	string _getValue(string section, string key, int useDef)
	{
		//useDef 0: kdsCst / 1: kdsDef / 2: kdsDef if kdsCst is empty
		dictionary kds = useDef == 1 ? kdsDef : kdsCst;
		dictionary _kds;
		if (kds.get(section, _kds))
		{
			KeyData kd;
			if (_kds.get(key, kd))
			{
				if (useDef == 1 || kd.state == 1) return kd.value;
			}
			else
			{
				if (useDef == 1 && key.Left(1) != "#")
				{
					return _getValue(section, "#" + key, 1);
				}
			}
		}
		return useDef == 2 ? _getValue(section, key, 1) : "";
	}
	
	string getStr(string section, string key)
	{
		return _getValue(section, key, 2).Trim("\"");
	}
	
	int getInt(string section, string key)
	{
		return parseInt(_getValue(section, key, 2));
	}
	
	string _setValue(string section, string key, string setValue)
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
					kd.areaStr = _getCfgStr(true, section, key);
					if (kd.areaStr.empty())
					{
						kd.areaStr = _getCfgStr(true, section, "#" + key);
						if (kd.areaStr.Left(1) == "#") kd.areaStr = kd.areaStr.substr(1);
					}
					_parseKeyData(kd);
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
				_saveFile();
				return prevValue;
			}
			else
			{
HostPrintUTF8("no key: " + key);
			}
		}
		return "";
	}
	
	string setStr(string section, string key, string sValue)
	{
		string prevValue = _setValue(section, key, sValue);
		return prevValue.Trim("\"");
	}
	
	int setInt(string section, string key, int iValue)
	{
		string prevValue = _setValue(section, key, formatInt(iValue));
		return parseInt(prevValue);
	}
	
};

CFG cfg;

//----------------------- class CFG end -------------------------


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
				if (cfg.getStr("MAINTENANCE", "ytdlp_hash").empty())
				{
					string msg = "You are using newly placed [yt-dlp.exe].";
					HostMessageBox(msg, "[yt-dlp]", 2, 0);
					cfg.setStr("MAINTENANCE", "ytdlp_hash", hash);
				}
				else if (hash != cfg.getStr("MAINTENANCE", "ytdlp_hash"))
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
						cfg.setStr("MAINTENANCE", "ytdlp_hash", hash);
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
		cfg.setInt("MAINTENANCE", "critical_error", 1);
		cfg.deleteKey("MAINTENANCE", "update_ytdlp");
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
		
		int top0;
		do {
			top0 = top;
			if (top > 0) top += 1;
			int end = str.find("}\n", top);
			if (end < 0) break;
			end += 1;
			string entry = str.substr(top, end - top);
			entries.insertLast(entry);
			posLog = end + 1;
			top = str.find("\n{", end);
		} while (top > top0);
		
		return entries;
	}
	
	array<string> waitOutputs;
	
	array<string> exec(string url, bool isPlaylist)
	{
		ytd.checkYtdlpInfo();
		if (error != 0) return {};
		
		if (cfg.consoleOut > 0) HostOpenConsole();
		
		string options = "";
		
		int woi = waitOutputs.find(url);
		
		if (!isPlaylist)	//a single video/audio
		{
			if (woi >= 0 )
			{
				waitOutputs.removeAt(woi);
				if (cfg.consoleOut > 0) HostPrintUTF8("\r\n[yt-dlp] Unsupported - \"" + url +"\"\r\n");
				return {};
			}
			
			if (cfg.consoleOut > 0) HostPrintUTF8("\r\n[yt-dlp] Parsing... - \"" + url +"\"\r\n");
			
			options += " -I 1";
			
			//using cookie
			bool isCookie = false;
			if (cfg.getStr("COOKIE", "cookie_file").size() > 3)
			{
				options = " --cookies \"" + cfg.getStr("COOKIE", "cookie_file") + "\"";
				isCookie = true;
			}
			else if (cfg.getStr("COOKIE", "browser_name").size() > 3)
			{
				options = " --cookies-from-browser \"" + cfg.getStr("COOKIE", "browser_name") + "\"";
				isCookie = true;
			}
			if (isCookie)
			{
				if (cfg.getStr("YOUTUBE", "potoken_bgutil_script").size() > 10)
				{
					options += " --extractor-args \"youtube:getpot_bgutil_script=" + cfg.getStr("YOUTUBE", "potoken_bgutil_script") + "\"";
				}
				if (cfg.getStr("YOUTUBE", "potoken_bgutil_baseurl").size() > 10)
				{
					options += " --extractor-args \"youtube:getpot_bgutil_baseurl=" + cfg.getStr("YOUTUBE", "potoken_bgutil_baseurl") + "\"";
				}
				if (cfg.getStr("YOUTUBE", "potoken_direct").size() > 10)
				{
					options += " --extractor-args \"youtube:po_token=web.gvs+" + cfg.getStr("YOUTUBE", "potoken_direct") + "\"";
				}
			}
			
			if (cfg.getInt("COOKIE", "mark_watched") == 1) options += " --mark-watched";
			if (cfg.getInt("YOUTUBE", "live_from_start") == 1) options += " --live-from-start";
		}
		else	//playlist
		{
			if (woi >= 0 ) return {};
			
			if (cfg.consoleOut > 0) HostPrintUTF8( "\r\n[yt-dlp] Extracting playlist entries... - \"" + url +"\"\r\n");
			
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
		
		if (cfg.getStr("NETWORK", "proxy").size() > 3) options += " --proxy \"" + cfg.getStr("NETWORK", "proxy") + "\"";
		
		if (cfg.getInt("NETWORK", "ip_version") == 4) options += " -4";
		else if (cfg.getInt("NETWORK", "ip_version") == 6) options += " -6";
		
		if (cfg.getInt("NETWORK", "no_check_certificates") == 1) options += " --no-check-certificates";
		
		if (cfg.consoleOut > 1) options += " -v";	//Verbose log
		
		if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 1) options += " -U";
		
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
		
		if (cfg.consoleOut == 1)
		{
			string log = output.substr(posLog).TrimLeft("\r\n");
			if (!log.empty()) HostPrintUTF8(log);
		}
		else if (cfg.consoleOut == 2)
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
				if (cfg.consoleOut > 0) HostPrintUTF8("[yt-dlp] Unsupported. - \"" + url +"\"\r\n");
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
	if (cfg.getInt("MAINTENANCE", "critical_error") != 0) ytd.error = 3;
	if (ytd.error > 0) scriptName += " " + ytd.errors[ytd.error];
	else if (cfg.getInt("SWITCH", "stop") == 1) scriptName += " (STOP)";
	else if (cfg.getStr("COOKIE", "cookie_file").size() > 3) scriptName += " (cookie file)";
	else if (cfg.getStr("COOKIE", "browser_name").size() > 3) scriptName += " (cookie " + cfg.getStr("COOKIE", "browser_name") + ")";
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
cfg.setInt("YOUTUBE", "live_from_start", 1);
	//called when opening info panel
	if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 2)
	{
		ytd.updateVersion();
		cfg.setInt("MAINTENANCE", "update_ytdlp", 0);
	}
	else
	{
		ytd.checkYtdlpInfo();
	}
	
	const string SITE_DEV = "https://github.com/yt-dlp/yt-dlp";
	const string SITE_DESC = "https://github.com/hgcat-360/PotPlayer-Extension-by-yt-dlp";
	string info =
		"<a href=\"" + SITE_DEV + "\">yt-dlp development (github)</a>\r\n"
		"<a href=\"" + SITE_DESC + "\">Distribution of this extention (github)</a>\r\n"
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
	
	if (cfg.getInt("MAINTENANCE", "critical_error") != 0) ytd.error = 3;
	if (ytd.error == 3 || cfg.getInt("SWITCH", "stop") == 1) return false;
	
	path.MakeLower();
	
	if (!HostRegExpParse(path, "^https?://", {})) return false;
	
	if (HostRegExpParse(path, "//192\\.168\\.\\d+\\.\\d+\\b", {})) return false;
		//Exclude LAN
	
	if (cfg.getInt("YOUTUBE", "enable_youtube") == 0 && _IsYoutubeUrl(path)) return false;
		//Exclude youtube according to the setting
	
	if (HostRegExpParse(path, "//(?:[-\\w.]+\\.)?kakao\\.com(?:[/?#].*)?$", {})) return false;
		//Exclude KakaoTV
	
	string ext = _GetUrlExtension(path);
	if (!ext.empty())	//hot-link to a web file
	{
		int kind = 0x0;
		if (cfg.getInt("TARGET", "hotlink_media_file") < 1) kind |= 0x111;	//Exclude media files
		if (cfg.getInt("TARGET", "hotlink_playlist_file") < 1) kind |= 0x1000;	//Exclude playlist files
		kind |= 0x110000;	//Exclude compressed/subtitles files
		if (_CheckExt(ext, kind)) return false;
	}
	
	return true;
}


string _OmitStr(string str, string search, int cnt = 1)
{
	if (cnt < 1) return str;
	int pos = 0;
	for (int i = 0; i < cnt; i++)
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
	
	array<string> entries = ytd.exec(path, false);
	if (entries.size() == 0) return "";
	
	string json = entries[0];
	JsonReader reader;
	JsonValue root;
	if (!reader.parse(json, root) || !root.isObject())
	{
		if (cfg.consoleOut > 0) HostPrintUTF8("[yt-dlp] ERROR! Json data corrupted.\r\n");
		return "";
	}
	JsonValue jVersion = root["_version"];
	if (!jVersion.isObject()) {ytd.criticalError(); return "";}
	else
	{
		string version = _GetJsonValueString(jVersion, "version");
		if (version.empty()) {ytd.criticalError(); return "";}
		else
		{
			if (version != ytd.version)
			{
				if (cfg.getInt("MAINTENANCE", "update_ytdlp") == 1)
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
		if (cfg.consoleOut > 0) HostPrintUTF8("[yt-dlp] ERROR! No extractor.\r\n");
		return "";
	}
	string webUrl = _GetJsonValueString(root, "webpage_url");
	if (webUrl.empty())
	{
		if (cfg.consoleOut > 0) HostPrintUTF8("[yt-dlp] ERROR! No webpage url.\r\n");
		return "";
	}
	
	int playlistIdx = _GetJsonValueInt(root, "playlist_index");
	if (playlistIdx > 0 && path != webUrl)
	{
		//Exclude playlist url
		if (cfg.consoleOut > 0) HostPrintUTF8("[yt-dlp] ERROR! This url is for playlist. You need to fetch url of each entry in it. - \"" + path +"\"\r\n");
		return "";
	}
	bool isLive = _GetJsonValueBool(root, "is_live");
	if (isLive && cfg.getInt("YOUTUBE", "no_youtube_live") == 1 && _IsYoutubeUrl(path))
	{
		if (cfg.consoleOut > 0) HostPrintUTF8("[yt-dlp] YouTube live is passed through by \"no_youtube_live\". - \"" + path +"\"\r\n");
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
		if (isAudioExt && cfg.getInt("TARGET", "radio_thumbnail") == 1)
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
	
	JsonValue jFormats = root["formats"];
	if (!jFormats.isArray() || jFormats.size() == 0)
	{
		//Don't treat it as an error.
		//For getting uploader(website) or thumbnail or upload date.
		if (cfg.consoleOut > 0) HostPrintUTF8("[yt-dlp] No \"formats\" data...\r\n");
	}
	
	uint vaCount = 0;
	uint vCount = 0;
	uint aCount = 0;
	for (int i = jFormats.size() - 1; i >= 0 ; i--)
	{
		JsonValue jFormat = jFormats[i];
		
		string protocol = _GetJsonValueString(jFormat, "protocol");
		if (protocol.empty()) continue;
		if (protocol != "http" && protocol != "https" && protocol.Left(4) != "m3u8") continue;
		
		int qualityIdx = _GetJsonValueInt(jFormat, "quality");
		
		string fmtUrl = _GetJsonValueString(jFormat, "url");
		if (fmtUrl.empty()) continue;
		if (urlOut.empty()) urlOut = fmtUrl;
		
		if (@QualityList !is null)
		{
			string fmtExt = _GetJsonValueString(jFormat, "ext");
			string vExt = _GetJsonValueString(jFormat, "video_ext");
			string aExt = _GetJsonValueString(jFormat, "audio_ext");
			if (fmtExt.empty() || vExt.empty() || aExt.empty()) continue;
			
			string vcodec = _GetJsonValueString(jFormat, "vcodec");
			vcodec = _OmitStr(vcodec, ".", 1);
			
			string acodec = _GetJsonValueString(jFormat, "acodec");
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
			
			int width = _GetJsonValueInt(jFormat, "width");
			if (width > 0 && cfg.getInt("FORMAT", "reduce_low_quality") == 1)
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
			
			int height = _GetJsonValueInt(jFormat, "height");
			if (height > 0 && cfg.getInt("FORMAT", "reduce_low_quality") == 1)
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
			
			float abr = _GetJsonValueFloat(jFormat, "abr");
			if (abr > 0 && cfg.getInt("FORMAT", "reduce_low_quality") == 1)
			{
				if (va == "a")
				{
					if (abr < 100 && aCount >= 2) continue;
				}
			}
			
			float vbr = _GetJsonValueFloat(jFormat, "vbr");
			float tbr = _GetJsonValueFloat(jFormat, "tbr");
			
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
				if (!language.empty())
				{
					note = _GetJsonValueString(jFormat, "format_note");
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
				quality = _GetJsonValueString(jFormat, "format_id");
				if (quality.empty())
				{
					quality = _GetJsonValueString(jFormat, "format");
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
						dictionary dic;
						dic["langCode"] = langCode;
						dic["url"] = subUrl;
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
									if (subExt.find("vtt") >= 0 || subExt.find("srv") >= 0)
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
						float cTime = _GetJsonValueFloat(jChapter, "start_time");
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
	
	if (cfg.consoleOut > 0) HostPrintUTF8("[yt-dlp] Parsing completed by " + extractor + ". - \"" + path +"\"\r\n");
	return urlOut;
}


bool PlaylistCheck(const string &in path)
{
	//called when a new item is being opend from a location other than potplayer's playlist
	//Some playlist extraction may freeze yt-dlp.
	
	if (!PlayitemCheck(path)) return false;
	
	if (_IsYoutubeUrl(path))
	{
		if (cfg.getInt("YOUTUBE", "enable_youtube") < 2) return false;
	}
	else
	{
		if (cfg.getInt("TARGET", "website_playlist") < 1) return false;
	}
	
	string ext = _GetUrlExtension(path);
	if (!ext.empty())
	{
		if (_CheckExt(ext, 0x110111)) return false;
		if (_CheckExt(ext, 0x1000))
		{
			if (cfg.getInt("TARGET", "hotlink_playlist_file") < 2) return false;
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
			if (thumbnail.empty())
			{
				if (isAudioExt && cfg.getInt("TARGET", "radio_thumbnail") == 1)
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
	int cnt = 0;
	for (uint i = 0; i < entries.size(); i++)
	{
		dictionary dic = _PlaylistParse(entries[i]);
		string urlEntry;
		if (dic.get("url", urlEntry) && !urlEntry.empty())
		{
			int idx = int(dic["playlistIdx"]);
			if (idx > 0)
			{
				if (cfg.consoleOut > 0)
				{
					if (cnt == 0)
					{
						string extractor;
						if (dic.get("extractor", extractor) && !extractor.empty())
						{
							HostPrintUTF8("Extractor: " + extractor);
						}
					}
					HostPrintUTF8("Url " + idx + ": " + urlEntry);
				}
				dicsEntry.insertLast(dic);
				cnt++;
			}
		}
	}
	
	if (cfg.consoleOut > 0) HostPrintUTF8("[yt-dlp] Playlist entries: " + cnt + "    - \"" + path +"\"\r\n");
	return dicsEntry;
}


