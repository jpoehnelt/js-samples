load("@npm//nunjucks-cli:index.bzl", npm_nunjucks = "nunjucks")
load("//rules:strip_region_tags.bzl", "strip_region_tags")
load("//rules:prettier.bzl", "prettier")
load("//rules:inline.bzl", "inline")

def _set_data_field(name, src, out, field, value):
    native.genrule(
        name = name,
        cmd = "./$(location //rules:json) -f $(location {}) -e 'this.{}={}' > $@".format(src, field, value),
        srcs = [src],
        tools = ["//rules:json"],
        outs = [out],
    )

def html_render():
    native.genrule(
        name = "_data_key",
        cmd = "$(location //rules:json) -f $(location data.json) -e \"this.key='$$GOOGLE_MAPS_JS_SAMPLES_KEY'\" > $@",
        srcs = [":data.json"],
        tools = ["//rules:json"],
        outs = ["_data_key.json"],
    )

    _jsfiddle(name="jsfiddle_html", src=":src/index.njk", out="jsfiddle.html", data=":_data_key.json")
    _normal(name="index_html", src=":src/index.njk", out="index.html", data=":_data_key.json")
    _inline(name="inline_html", src=":src/index.njk", out="inline.html", data=":_data_key.json")

def _render(name, src, data, out, templates="//shared:templates"):
    tmp_name = name + "_tmp"
    tmp_name_out = name + "_tmp_out.html"
    
    npm_nunjucks(
        name = tmp_name,
        args = [
            "$(location {})".format(src),
            "-p",
            ".",
            "$(location {})".format(data),
            "--out",
            "$@",
        ],
        data = [
            src,
            data,
            templates,
        ],
        output_dir = True,
    )

    # this genrule moves the generated html file to the correct location
    # nunjucks-cli does not allow specifying a single output file
    # nunjucks-cli converts the .njk to a .html by default
    native.genrule(
        name = name,
        srcs = [tmp_name],
        cmd = "cat $(location {})/{}/src/index.html > $@".format(tmp_name, native.package_name()),
        outs = [tmp_name_out],
        visibility = ["//visibility:public"],
    )

    prettier(
        src = tmp_name_out,
        out = out
    )

def _jsfiddle(name, src, out, data):
    _set_data_field(
        name = "_data_jsfiddle",
        src = ":_data_key.json",
        out = "_data_jsfiddle.json",
        field = "jsfiddle",
        value = "true"
    )
   
    _render(
        name = name,        
        data = ":_data_jsfiddle.json",
        src = ":src/index.njk",  
        out = "_jsfiddle_raw.html"  
    )

    strip_region_tags(
        name = "_jsfiddle_strip_region_tags",
        input = ":_jsfiddle_raw.html",
        output = out,
    )

def _normal(name, src, out, data):
    _render(
        name =  name,        
        data = data,
        out = out,
        src = src,    
    )

def _inline(name, src, out, data):
    _set_data_field(
        name = "_data_inline",
        src = data,
        out = "_data_inline.json",
        field = "inline",
        value = "true"
    )
   
    _render(
        name = name,        
        data = ":_data_inline.json",
        src = src,  
        out = out  
    )

    inline(
        src=out,
        out="inlined.html",
        sources = [":transpiled.js", "style.css"]
    )



