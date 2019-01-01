component output="false" {


variables.langRoot = expandPath("./lang");
variables.cache = {language : "i18n_lang"}


array function getLang() output="false"	{
	var AllIDs = cacheGetAllIds(variables.cache.language);


	AllIDs.each(function(ID, index, AllIDs){
		AllIDs[index] = cacheGetMetadata(ID, "template", variables.cache.language);
		AllIDs[index].lang = ID;
	});

	return AllIDs;
}


void function setupRequest() output="false"	{

	if(!cacheRegionExists(variables.cache.language)) CacheRegionNew(variables.cache.language);


	// note: renaming application will not load new languages, you have to restart the cf service
	if(cacheGetAllIds(variables.cache.language).isEmpty())	{

		var i18n = {};
		i18n.append(readPHP(variables.langroot) );				// traditional language file

		for (var languageKey in i18n)	{
			CachePut(languageKey, i18n[languageKey], 1, 1, variables.cache.language);
			}

		}
}



string function geti18n(required string key, any placeholder = [], string lang = "en-US") {


	// lang could be powered by cgi.HTTP_ACCEPT_LANGUAGE
	var arLang = cacheGetAllIds(variables.cache.language);

	var final_lang = "";
	for (var accept_lang in ListToArray(canonicalize(arguments.lang, true, true)))	{
		if (ArrayContainsNoCase(arLang, accept_lang.listfirst(";")))	{
			final_lang = accept_lang.listfirst(";");
			break;
		}
	}

	if (final_lang == "")	{
		return "Error in processing: " & final_lang;
	}


	arguments.lang = arguments.lang.listfirst();


	if (!isArray(arguments.placeholder)) {
		arguments.placeholder = [arguments.placeholder]
		};

	if (CacheIdExists(arguments.lang, variables.cache.language))	{

		var stLang = cacheGet(arguments.lang, variables.cache.language);
		if (stLang.keyExists(arguments.key))	{

			var myString = stLang[arguments.key];

			for (var i in arguments.placeholder)	{

				myString = myString.replace('%s', i); // only does first match
				}

			return getSafeHTML(myString);
			} // end keyExists
		} // end cacheIdExists


	return "{#arguments.key#}"; // This is string, it is not intended to be valid JSON
}


private struct function readProperties(required string propertyfile)	output="false"	{

	var stResult = {};

	var stSection = getProfileSections(arguments.propertyfile.replace("\", "/", "all"));

	for(var section in stSection)	{
		var stData = {};

		for(var key in stSection[section].listToArray())	{
			stData[key] = getProfileString(arguments.propertyfile, section, key);
			}

		stResult[section] = stData;
	}

	return stResult;
}


// This is not a fool proof way of reading PHP language files, but it should allow for some univerality
private struct function readPHP(required string phpPath)	output="false"		{

	var stProperties = {};

	var arDirectory = DirectoryList(arguments.phpPath, false, "path", "*.php");

	for (var phpFile in arDirectory)	{

		phpFile = phpFile.replace("\", "/", "all");

		var languageKey = phpFile.listLast("/").listFirst(".").replacelist("_", "-");

		stProperties[languageKey] = { "_reading" : phpFile };

		phpText = fileRead(phpFile).trim();


		// remove comments and blank lines
		phpText = phpText.ReReplace("(?m)\##.*?$", "", "all")
					.ReReplace("[#Chr(10)#]{2,}", chr(10), "all")
					.ReplaceList('",', '"');


		// loop over each line, ignore comments (#...) and insert keys/values into return struct
		for(var line in phpText.ListToArray(chr(10)))	{

			var splitAt 	= line.find("=>");
			var commentAt  = line.find("//");

			try	{
				if (splitAt != 0)	{

					var key = line.left(splitAt - 1).trim().replacelist('"', "")
							.replace(',', '', 'all')
							.replace("'", "", 'all')
							.trim();

					var value = line.find("//") ?
							line.mid(splitAt + 2, CommentAt - (splitAt + 2)	).trim().replacelist('"', '')
							:
							line.mid(splitAt + 2, 1000					).trim().replacelist('"', '')
							;

					// Remove trailing ,
					if (value.right(1) == ",")
						value = value.mid(1, value.len() - 1);


					if (value.right(1) == "'")
						value = value.mid(1, value.len() - 1);

					if (value.left(1) == "'")
						value = value.mid(2, 1000);


					stProperties[languageKey][key] = value;
				} // valid split at
			}	
			catch (any e) {
				}
			

		} // end line
	} // end file

	return stProperties;

} // end function



} // end component
