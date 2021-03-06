module: gir-generate-c-ffi
synopsis: generate c-ffi bindings using gobject-introspection
author: Bruce Mitchener, Jr.
copyright: See LICENSE file in this distribution.

define function parse-args
    (args :: <sequence>)
 => (parser :: <command-line-parser>)
  let parser = make(<command-line-parser>);
  add-option(parser,
             make(<optional-parameter-option>,
                  names: #("version"),
                  default: #f,
                  help: "Version of the library to generate bindings for. Defaults to most recent."));
  // XXX: Should add a repeated-option-parameter for the search path.
  block ()
    parse-command-line(parser, args,
                       usage: "gir-generate-c-ffi [options] namespaces...",
                       description: "Generates C-FFI bindings from gobject-introspection data.");
  exception (ex :: <help-requested>)
    exit-application(0);
  exception (ex :: <usage-error>)
    exit-application(2);
  end;
  parser
end;

define function main (arguments :: <sequence>)
  let parser = parse-args(arguments);
  let namespaces = positional-options(parser);
  let version = as(<C-string>, get-option-value(parser, "version") | null-pointer(<C-string>));
  // XXX: Fail nicely if no namespaces.
  // XXX: Fail if they specify a version and more than one namespace.
  for (namespace in namespaces)
    if (load-typelib(namespace, version))
      generate-c-ffi(namespace, version);
    end if;
  end for;
end function;

define function load-typelib
    (namespace :: <string>, version :: <string>)
 => (loaded? :: <boolean>)
  let repo = g-irepository-get-default();
  let (typelib, error) = g-irepository-require(repo, namespace, version, 0);
  if (~null-pointer?(error) | null-pointer?(typelib))
    if (null-pointer?(version))
      format(*standard-error*, "No versions of %s are available.\n", namespace);
    else
      format(*standard-error*, "Version %s of %s is not available.\n", version, namespace);
    end if;
    force-output(*standard-error*);
    #f
  else
    #t
  end if
end function;

main(application-arguments());
