##Contribute to CMScan
CMScan is an open source framework to detect vulnerable plugins installed in your web application(CMS) using simple port scanning technique (NMAP). Your contribution to the CMScan is highly appreciated.
**Creating new CMS Entry**
In order to create a new cms entry, a json file to be updated with the new CMS details. The details contain cms_name,cms_version_file_directory,cms_plugin_directory alogn with version_file_directory

Example:
[{"cms_name":"wordpress","cms_version_file_directory":"/readme.html","cms_plugin_directory":["/contents","/uploads"]}]

**Creating List of extensions available for the new CMS Entry**

create a file for new cms with name cmsname_extensions.txt .The cmsname should be your cms name.
extension_name each in new line.


**Creating List of vulnerable extensions available for the new CMS Entry**

create a file for vulnerable_plugin for a new cms  cmsname_vulnerable_extensions.txt. The cmsname should be your cms name.
The details should be contained in a json file, like:

[{"vulnerable_plugin":"jetpack","affected_version":["4.5","2.1"],"description_of_vulnerability":"SQL Injection","code_type":["cve","exploitdb"],"code":[{"cve":"21343","exploitdb":"1312"}],"source_url":["",""]}]

You can also make pull request to update the existing files.
