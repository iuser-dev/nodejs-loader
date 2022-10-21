#!/usr/bin/env coffee

import { existsSync, readFileSync } from "fs"
import { createRequire } from "module"
import { dirname, normalize, extname, join, resolve as resolvePath } from "path"
import { cwd } from "process"
import { fileURLToPath, pathToFileURL } from "url"
import CoffeeScript from "coffeescript"
import {coffee_plus} from 'coffee_plus'

compile = coffee_plus(CoffeeScript)

baseURL = pathToFileURL("#{cwd}/").href

not_coffee = (specifier)=>
  specifier.slice(specifier.lastIndexOf(".") + 1) != 'coffee'

JS_SUFFIX = '.js'

jsext = (specifier)=>
  if specifier.startsWith '@'
    begin = specifier.indexOf('/',1)+1
  else
    begin = 1

  pos = specifier.indexOf('/',begin)
  if pos > 0 and not specifier[pos+1..].split('/').pop().includes('.')
    specifier+=JS_SUFFIX
  specifier

export resolve = (specifier, context, defaultResolve) =>
  { parentURL = baseURL } = context

  if not_coffee(specifier)
    :$
      loop
        if parentURL.startsWith('file://')
          for prefix from ['./','../']
            if specifier.startsWith prefix
              file = specifier+'.coffee'
              fp = normalize join dirname(parentURL[7..]),file
              if existsSync fp
                specifier = fp
                break $
        return defaultResolve(jsext(specifier), context, defaultResolve)

  {
    shortCircuit: true,
    url: new URL(specifier, parentURL).href
  }


export load = (url, context, defaultLoad)=>
  if url.endsWith('.node')
    return {
      format:'commonjs'
    }

  if not_coffee(url)
    return defaultLoad(url, context, defaultLoad)
  format = getPackageType(url)
  if format == "commonjs"
    return { format }

  { source: rawSource } = await defaultLoad(url, { format })
  transformedSource = compile(rawSource.toString(), {
    bare: true,
    filename: url,
    inlineMap: true,
  })

  return {
    format
    shortCircuit: true
    source: transformedSource,
  }

getPackageType = (url) =>
  isFilePath = !!extname(url)
  dir = if isFilePath then dirname(fileURLToPath(url)) else url
  packagePath = resolvePath(dir, "package.json")
  try
    {type} = JSON.parse readFileSync(packagePath, { encoding: "utf8" })
  catch err
    if err?.code != "ENOENT"
      console.error(err)
  if type
    return type
  return dir.length > 1 and getPackageType(resolvePath(dir, ".."))
