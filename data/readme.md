##Contribution
Everytime, new Content Management Systems can be added to the repository by adding the lists following the instructed conventions. There is a *cms_details.json* file which contains the details about the CMS in an array. In order to append a new CMS in the framework, the *cms_details.json* must be updated with the new CMS name, CMS version file directory and array of CMS extension file directory. 
```
[{
  "cms_name": "example",
  "cms_version_file_directory": "/example.txt",
    "cms_extension_directory": [
      "/directory_1",
      "/directory_2"
    ]
}]
```
The *cms_version_directory* is the directory path of a file that contains version of the installed CMS and the *cms_plugin_directory* contains the array of the directories those contain the installed extensions.

There are two other files to be created for each CMS. One is the 
 *cmsname_extension.json* that contains all the extensions available for installation in the *cmsname* CMS in the following syntax: 
```
[{
  "extension": "example",
  "directory": "/example.txt"
}]
```
It is also possible to accommodate the extensions when all the extension's version file reside in the same directory with the JSON file like-
```
[{
  "extension": ["example_1","example_2"],
  "directory": "/example.txt"
}]
```

If the file name or directory name that contains the version becomes the same name as the extension, it can be written as-
```
[{
  "extension": ["example_1","example_2"],
  "directory": "/{ext}/{ext}.txt"
}]
```
Here 'ext' will be replaced with the extension name in the Operational Stage.
Another file to be created with each CMS with the name *cmsname_vulnerable_extensions.json* that contains all the vulnerable extensions along with the list of affected versions for *cmsname* CMS in the syntax-
```
[{
    "vulnerable_plugin":"vulnerable_plugin_name",
    "affected_version":["4.5","2.1"],
    "description_of_vulnerability":"SQLInjection",
    "code_type":["cve","exploitdb"],
    "code":[{"cve":"xxxxx","exploitdb":"xxxxx"}],
    "source_url":["https://example.com/xxxx/",
    "https://example.com/xxxx"
    ]}]
```
The following syntax may be changed and will be updated accordingly in the document of this repository.
