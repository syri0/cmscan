local shortport = require "shortport"
local http = require "http"
local stdnse = require "stdnse"
local table = require "table"
local target= require "target"
local coroutine = require "coroutine"
local io = require "io"
local nmap = require "nmap"
local string = require "string"


-- The Rule Section --
portrule = shortport.http

------for wp--
categories = {"discovery", "intrusive"}

local DEFAULT_SEARCH_LIMIT = 40
local DEFAULT_PLUGINS_PATH = '/wp-content/plugins/'
local WORDPRESS_API_URL = 'http://api.wordpress.org/plugins/info/1.0/'

---drupal--

local DEFAULT_MODULES_PATH = 'sites/all/modules/'
local DEFAULT_THEMES_PATH = 'sites/all/themes/'
local IDENTIFICATION_STRING = "GNU GENERAL PUBLIC LICENSE"

--wp--
portrule = shortport.http
--Reads database
local function read_data_file(file)
  return coroutine.wrap(function()
    for line in file:lines() do
      if not line:match("^%s*#") and not line:match("^%s*$") then
        coroutine.yield(line)
      end
    end
  end)
end
--drupal---
local function read_data(file)
  return coroutine.wrap(function()
    for line in file:lines() do
      if not line:match("^%s*#") and not line:match("^%s*$") then
        coroutine.yield(line)
      end
    end
  end)
end

--Checks if the plugin/theme file exists
local function existence_check_assign(act_file)
  if not act_file then
    return false
  end
  local temp_file = io.open(act_file,"r")
  if not temp_file then
    return false
  end
  return temp_file
 end

--Obtains version from readme.txt or style.css
local function get_version(path, typeof, host, port)
  local pattern, version, versioncheck

  if typeof == 'plugins' then
    path = path .. "readme.txt"
    pattern = 'Stable tag: ([.0-9]*)'
  else
    path = path .. "style.css"
    pattern = 'Version: ([.0-9]*)'
  end

  stdnse.debug1("Extracting version of path:%s", path)
  versioncheck = http.get(host, port, path)
  if versioncheck.body then
    version = versioncheck.body:match(pattern)
  end
  stdnse.debug1("Version found: %s", version)
  return version
end

-- check if the plugin is the latest
local function get_latest_plugin_version(plugin)
  stdnse.debug1("Retrieving the latest version of %s", plugin)
  local apiurl = WORDPRESS_API_URL .. plugin .. ".json"
  local latestpluginapi = http.get('api.wordpress.org', '80', apiurl)
  local latestpluginpattern = '","version":"([.0-9]*)'
  local latestpluginversion = latestpluginapi.body:match(latestpluginpattern)
  stdnse.debug1("Latest version:%s", latestpluginversion)
  return latestpluginversion
end

-------end for wp

function wp(host, port)

  local result = {}
  local file = {}
  local all = {}
  local bfqueries = {}
  local wp_autoroot
  local output_table = stdnse.output_table()
  --Read script arguments
  local operation_type_arg = stdnse.get_script_args(SCRIPT_NAME .. ".type") or "all"
  local apicheck = stdnse.get_script_args(SCRIPT_NAME .. ".check-latest")
  local wp_root = stdnse.get_script_args(SCRIPT_NAME .. ".root")
  local resource_search_arg = stdnse.get_script_args(SCRIPT_NAME .. ".search-limit") or DEFAULT_SEARCH_LIMIT

  local wp_themes_file = nmap.fetchfile("nselib/data/wp-themes.lst")
  local wp_plugins_file = nmap.fetchfile("nselib/data/wp-plugins.lst")

  if operation_type_arg == "themes" or operation_type_arg == "all" then
    local theme_db = existence_check_assign(wp_themes_file)
    if not theme_db then
      return false, "Couldn't find wp-themes.lst in /nselib/data/"
    else
      file['themes'] = theme_db
    end
  end
  if operation_type_arg == "plugins" or operation_type_arg == "all" then
    local plugin_db = existence_check_assign(wp_plugins_file)
    if not plugin_db then
      return  false, "Couldn't find wp-plugins.lst in /nselib/data/"
    else
      file['plugins'] = plugin_db
    end
  end

  local resource_search
  if resource_search_arg == "all" then
    resource_search = nil
  else
    resource_search = tonumber(resource_search_arg)
  end

  -- Identify servers that answer 200 to invalid HTTP requests and exit as these would invalidate the tests
  local status_404, result_404, known_404 = http.identify_404(host,port)
  if ( status_404 and result_404 == 200 ) then
    stdnse.debug1("Exiting due to ambiguous response from web server on %s:%s. All URIs return status 200.", host.ip, port.number)
    return nil
  end

  -- search the website root for evidences of a Wordpress path
  if not wp_root then
    local target_index = http.get(host,port, "/")

    if target_index.status and target_index.body then
      wp_autoroot = string.match(target_index.body, "http://[%w%-%.]-/([%w%-%./]-)wp%-content")
      if wp_autoroot then
        wp_autoroot = "/" .. wp_autoroot
        stdnse.debug(1,"WP root directory: %s", wp_autoroot)
      else
        stdnse.debug(1,"WP root directory: wp_autoroot was unable to find a WP content dir (root page returns %d).", target_index.status)
      end
    end
  end

  --build a table of both directories to brute force and the corresponding WP resources' name
  local resource_count=0
  for key,value in pairs(file) do
    local l_file = value
    resource_count = 0
    for line in read_data_file(l_file) do
      if resource_search and resource_count >= resource_search then
        break
      end

    local target
    if wp_root then
      -- Give user-supplied argument the priority
      target = wp_root .. string.gsub(DEFAULT_PLUGINS_PATH, "plugins", key) .. line .. "/"
    elseif wp_autoroot then
      -- Maybe the script has discovered another Wordpress content directory
      target = wp_autoroot .. string.gsub(DEFAULT_PLUGINS_PATH, "plugins", key) .. line .. "/"
    else
      -- Default WP directory is root
      target = string.gsub(DEFAULT_PLUGINS_PATH, "plugins", key) .. line .. "/"
    end


    target = string.gsub(target, "//", "/")
    table.insert(bfqueries, {target, line})
    all = http.pipeline_add(target, nil, all, "GET")
    resource_count = resource_count + 1

  end
  -- release hell...
  local pipeline_returns = http.pipeline_go(host, port, all)
  if not pipeline_returns then
    stdnse.verbose1("got no answers from pipelined queries")
    return nil
  end
  local response = {}
  response['name'] = key
  for i, data in pairs(pipeline_returns) do
    -- if it's not a four-'o-four, it probably means that the plugin is present
    if http.page_exists(data, result_404, known_404, bfqueries[i][1], true) then
      stdnse.debug(1,"Found a plugin/theme:%s", bfqueries[i][2])
      local version = get_version(bfqueries[i][1],key,host,port)
      local output  = nil

      --We format the table for XML output
      bfqueries[i].path = bfqueries[i][1]
      bfqueries[i].category = key
      bfqueries[i].name = bfqueries[i][2]
      bfqueries[i][1] = nil
      bfqueries[i][2] = nil

      if version then
         output = bfqueries[i].name .." ".. version
         bfqueries[i].installation_version = version
         --Right now we can only get the version number of plugins through api.wordpress.org
	apicheck="true"
         if apicheck == "true" and key=="plugins" then
           local latestversion = get_latest_plugin_version(bfqueries[i].name)
           if latestversion then
             output = output .. " (latest version:" .. latestversion .. ")"
             bfqueries[i].latest_version = latestversion
           end
         end
      else
         output = bfqueries[i].name
     end
       output_table[bfqueries[i].name] = bfqueries[i]
       table.insert(response, output)
    end
  end
  table.insert(result, response)
  bfqueries={}
  all = {}

end
  local len = 0
  for i, v in ipairs(result) do len = len >= #v and len or #v end
  if len > 0 then
    output_table.title = string.format("Search limited to top %s themes/plugins", resource_count)
    result.name = output_table.title
    return output_table, stdnse.format_output(true, result)
  else
    if nmap.verbosity()>1 then
      return string.format("Nothing found amongst the top %s resources,"..
                         "use --script-args search-limit=<number|all> for deeper analysis)", resource_count)
    else
      return nil
    end
  end

end


------------for drupal--------------
--Checks if the module/theme file exists
local function assign_file (act_file)
  if not act_file then
    return false
  end
  local temp_file = io.open(act_file, "r")
  if not temp_file then
    return false
  end
  return temp_file
end

--- Attempts to find modules path
local get_path = function (host, port, root, type_of)
  local default_path
  if type_of == "themes" then
    default_path = DEFAULT_THEMES_PATH
  else
    default_path = DEFAULT_MODULES_PATH
  end
  local body = http.get(host, port, root).body or ""
  local pattern = "sites/[%w.-/]*/" .. type_of .. "/"
  local found_path = body:match(pattern)
  return found_path or default_path
end

----main of drupal--------

function drupal (host, port)
  local result = stdnse.output_table()
  local file = {}
  local all = {}
  local requests = {}
  local method = "HEAD"

  --Read script arguments
  local resource_type = stdnse.get_script_args(SCRIPT_NAME .. ".type") or "all"
  local root = stdnse.get_script_args(SCRIPT_NAME .. ".root") or "/"
  local search_limit = stdnse.get_script_args(SCRIPT_NAME .. ".number") or DEFAULT_SEARCH_LIMIT
  local themes_path = stdnse.get_script_args(SCRIPT_NAME .. ".themes_path")
  local modules_path = stdnse.get_script_args(SCRIPT_NAME .. ".modules_path")

  local themes_file = nmap.fetchfile "nselib/data/drupal-themes.lst"
  local modules_file = nmap.fetchfile "nselib/data/drupal-modules.lst"

  if resource_type == "themes" or resource_type == "all" then
    local theme_db = assign_file(themes_file)
    if not theme_db then
      return false, "Couldn't find drupal-themes.lst in /nselib/data/"
    else
      file['Themes'] = theme_db
    end
  end

  if resource_type == "modules" or resource_type == "all" then
    local modules_db = assign_file(modules_file)
    if not modules_db then
      return false, "Couldn't find drupal-modules.lst in /nselib/data/"
    else
      file['Modules'] = modules_db
    end
  end

  if search_limit == "all" then
    search_limit = nil
  else
    search_limit = tonumber(search_limit)
  end

  if not themes_path then
    themes_path = (root .. get_path(host, port, root, "themes")):gsub("//", "/")
  end
  if not modules_path then
    modules_path = (root .. get_path(host, port, root, "modules")):gsub("//", "/")
  end

  -- We default to HEAD requests unless the server returns
  -- non 404 (200 or other) status code

  local response = http.head(host, port, modules_path .. stdnse.generate_random_string(8) .. "/LICENSE.txt")
  if response.status ~= 404 then
    method = "GET"
  end

  for key, value in pairs(file) do
    local count = 0
    for resource_name in read_data(value) do
      count = count + 1
      if search_limit and count > search_limit then
        break
      end
      -- add request to pipeline
      if key == "Modules" then
        all = http.pipeline_add(modules_path .. resource_name .. "/LICENSE.txt", nil, all, method)
      else
        all = http.pipeline_add(themes_path .. resource_name .. "/LICENSE.txt", nil, all, method)
      end
      -- add to requests buffer
      table.insert(requests, resource_name)
    end

    -- send requests
    local pipeline_responses = http.pipeline_go(host, port, all)
    if not pipeline_responses then
      stdnse.print_debug(1, "No answers from pipelined requests")
      return nil
    end

    for i, response in ipairs(pipeline_responses) do
      -- Module exists if 200 on HEAD.
      -- A lot Drupal of instances return 200 for all GET requests,
      -- hence we check for the identifcation string.
      if response.status == 200 and (method == "HEAD" or (method == "GET" and response.body:match(IDENTIFICATION_STRING))) then
        result[key] = result[key] or {}
        table.insert(result[key], requests[i])
      end
    end
    requests = {}
    all = {}
  end

  if result['Themes'] or result['Modules'] then
    return result
  else
    if nmap.verbosity() > 1 then
      return string.format("Nothing found amongst the top %s resources," .. "use --script-args number=<number|all> for deeper analysis)", search_limit)
    else
      return nil
    end
  end

end


--end drupal---















----------end for drupal---------------



-- Detect if the server running web service

function detect_service(host,port)
	local uri = "/abc/"

    local response = http.get(host, port, uri)
    --mytable[1]="Web service found"
    if(response.status==200 or response.status==400 or response.status==404) then
    return port.number
    else return false
    end
end

---detect if website developed with worpress ------
function wp_check(host,port)
	local uri = "/wp-content/"
print("-----port--------:",port)
    local response = http.get(host, port, uri)
    --mytable[1]="Web service found"
	if(response.status==200) then 
	return true
	else return false
   end
end
---detect if website developed with drupal ------
function drupal_check(host,port)
	local uri = "/modules/"
print("-----port--------:",port)
    local response = http.get(host, port, uri)
    --mytable[1]="Web service found"
	if(response.status==403) then 
	return true
	else return false
   end
end









-- The Action Section --

action = function(host, port)
--local status, err = target.add("mist.ac.bd")
--print("status:",status)

local port=detect_service(host,port)
print("-------------Discovered port no: ",port)
if(port) then
	if(wp_check(host,port)) then
	print("Detected Wordpress\n")	
	return wp(host,port)
	elseif(drupal_check(host,port)) then 
		print("Detected Drupal\n")		
		return drupal(host,port)
	else 
			
		return "Running no CMS"
	end
else return "Not running web service"
end





end
