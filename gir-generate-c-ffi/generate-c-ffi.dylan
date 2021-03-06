module: gir-generate-c-ffi
synopsis: generate c-ffi bindings using gobject-introspection
author: Bruce Mitchener, Jr.
copyright: See LICENSE file in this distribution.

define class <context> (<object>)
  slot exported-bindings = #();
  constant slot output-stream :: <stream>,
    required-init-keyword: stream:;
end class;

define function add-exported-binding
    (context :: <context>, binding-name :: <string>)
 => ()
  context.exported-bindings := add(context.exported-bindings, binding-name);
end function;

define function generate-c-ffi
    (namespace :: <string>, version :: <string>)
 => ()
  let repo = g-irepository-get-default();
  let context = make(<context>, stream: *standard-output*);
  let count = g-irepository-get-n-infos(repo, namespace);
  for (i from 0 below count)
    let info = g-irepository-get-info(repo, namespace, i);
    let type = g-base-info-get-type(info);
    write-c-ffi(context, info, type);
    force-output(context.output-stream);
  end for;
end function;

define function name-for-type (type) => (name :: <string>)
  select (type)
    $GI-INFO-TYPE-ARG => "arg";
    $GI-INFO-TYPE-BOXED => "boxed";
    $GI-INFO-TYPE-CALLBACK => "callback";
    $GI-INFO-TYPE-CONSTANT => "constant";
    $GI-INFO-TYPE-ENUM => "enum";
    $GI-INFO-TYPE-FIELD => "field";
    $GI-INFO-TYPE-FLAGS => "flags";
    $GI-INFO-TYPE-FUNCTION => "function";
    $GI-INFO-TYPE-INTERFACE => "interface";
    $GI-INFO-TYPE-INVALID => "invalid";
    $GI-INFO-TYPE-INVALID-0 => "invalid-0";
    $GI-INFO-TYPE-OBJECT => "object";
    $GI-INFO-TYPE-PROPERTY => "property";
    $GI-INFO-TYPE-SIGNAL => "signal";
    $GI-INFO-TYPE-STRUCT => "struct";
    $GI-INFO-TYPE-TYPE => "type";
    $GI-INFO-TYPE-UNION => "union";
    $GI-INFO-TYPE-UNRESOLVED => "unresolved";
    $GI-INFO-TYPE-VALUE => "value";
    $GI-INFO-TYPE-VFUNC => "vfunc";
    otherwise => "Unknown type";
  end select
end function;

define method write-c-ffi (context, info, type)
 => ()
  let name = g-base-info-get-name(info);
  let type-name = name-for-type(type);
  format(context.output-stream, "// Not set up yet for %s %s\n\n", type-name, name);
end method;

define method write-c-ffi (context, boxed-info, type == $GI-INFO-TYPE-BOXED)
 => ()
  // This is the same as a struct
  write-c-ffi(context, boxed-info, $GI-INFO-TYPE-STRUCT);
end method;

define method write-c-ffi (context, callback-info, type == $GI-INFO-TYPE-CALLBACK)
 => ()
  // We don't need to do anything for a callback. I think.
end method;

define method write-c-ffi (context, constant-info, type == $GI-INFO-TYPE-CONSTANT)
 => ()
  let name = g-base-info-get-name(constant-info);
  let dylan-name = map-name(#"constant", "", name, #[]);
  add-exported-binding(context, dylan-name);
  let type = g-constant-info-get-type(constant-info);
  let dylan-type = map-to-dylan-type(type);
  let value = "XXX";
  format(context.output-stream, "define constant %s :: %s = %s;\n\n", dylan-name,
             dylan-type, value);
end method;

define method write-c-ffi (context, enum-info, type == $GI-INFO-TYPE-ENUM)
 => ()
  let value-names = #[];
  let num-values = g-enum-info-get-n-values(enum-info);
  for (i from 0 below num-values)
    let value = g-enum-info-get-value(enum-info, i);
    let name = g-base-info-get-attribute(value, "c:identifier");
    let dylan-name = map-name(#"constant", "", name, #[]);
    add-exported-binding(context, dylan-name);
    value-names := add!(value-names, dylan-name);
    let integer-value = g-value-info-get-value(value);
    format(context.output-stream, "define constant %s :: <integer> = %d\n", dylan-name, integer-value);
    g-base-info-unref(value);
  end for;
  let enum-name  = g-base-info-get-name(enum-info);
  let dylan-enum-name = map-name(#"type", "", enum-name, #[]);
  add-exported-binding(context, dylan-enum-name);
  let joined-value-names = join(value-names, ", ");
  format(context.output-stream, "define constant %s = one-of(%s);\n\n", dylan-enum-name, joined-value-names);
end method;

define method write-c-ffi (context, flags-info, type == $GI-INFO-TYPE-FLAGS)
 => ()
  // This is the same as an enum
  write-c-ffi(context, flags-info, $GI-INFO-TYPE-ENUM)
end method;

define method write-c-ffi (context, function-info, type == $GI-INFO-TYPE-FUNCTION)
 => ()
  let name = g-base-info-get-name(function-info);
  let dylan-name = map-name(#"function", "", name, #[]);
  add-exported-binding(context, dylan-name);
  format(context.output-stream, "define C-function %s\n", dylan-name);
  let num-args = g-callable-info-get-n-args(function-info);
  for (i from 0 below num-args)
    let arg = g-callable-info-get-arg(function-info, i);
    let arg-name = g-base-info-get-name(arg);
    let arg-type = map-to-dylan-type(g-arg-info-get-type(arg));
    if (g-arg-info-is-return-value(arg))
      // XXX: We don't handle this. When does this happen?
    else
      let direction = direction-to-string(g-arg-info-get-direction(arg));
      format(context.output-stream, "  %s parameter %s :: %s;\n", direction, arg-name, arg-type);
    end if;
    g-base-info-unref(arg);
  end for;
  let result-type = g-callable-info-get-return-type(function-info);
  let dylan-result-type = map-to-dylan-type(result-type);
  format(context.output-stream, "  result res :: %s;\n", dylan-result-type);
  let symbol = g-function-info-get-symbol(function-info);
  format(context.output-stream, "  c-name: \"%s\";\n", symbol);
  format(context.output-stream, "end;\n\n");
end method;

define method write-c-ffi (context, interface-info, type == $GI-INFO-TYPE-INTERFACE)
 => ()
  format(context.output-stream, "interface\n");
end method;

define method write-c-ffi (context, object-info, type == $GI-INFO-TYPE-OBJECT)
 => ()
  let name = g-base-info-get-name(object-info);
  let dylan-name = map-name(#"type", "", name, #[]);
  add-exported-binding(context, dylan-name);
  format(context.output-stream, "define C-struct %s\n", dylan-name);
  let num-fields = g-object-info-get-n-fields(object-info);
  for (i from 0 below num-fields)
    let field = g-object-info-get-field(object-info, i);
    write-c-ffi-field(context, field, object-info);
  end for;
  format(context.output-stream, "end C-struct\n\n");
  let num-methods = g-object-info-get-n-methods(object-info);
  for (i from 0 below num-methods)
    let function-info = g-object-info-get-method(object-info, i);
    write-c-ffi(context, function-info, $GI-INFO-TYPE-FUNCTION);
  end for;
end method;

define method write-c-ffi (context, struct-info, type == $GI-INFO-TYPE-STRUCT)
 => ()
  let name = g-base-info-get-name(struct-info);
  let dylan-name = map-name(#"type", "", name, #[]);
  add-exported-binding(context, dylan-name);
  format(context.output-stream, "define C-struct %s\n", dylan-name);
  let num-fields = g-struct-info-get-n-fields(struct-info);
  for (i from 0 below num-fields)
    let field = g-struct-info-get-field(struct-info, i);
    write-c-ffi-field(context, field, struct-info);
  end for;
  format(context.output-stream, "end C-struct\n\n");
  let num-methods = g-struct-info-get-n-methods(struct-info);
  for (i from 0 below num-methods)
    let function-info = g-struct-info-get-method(struct-info, i);
    write-c-ffi(context, function-info, $GI-INFO-TYPE-FUNCTION);
  end for;
end method;

define method write-c-ffi (context, union-info, type == $GI-INFO-TYPE-UNION)
 => ()
  format(context.output-stream, "union\n");
end method;

define function write-c-ffi-field (context, field, container) => ()
  let field-name = map-name(#"field", "", g-base-info-get-name(field), #[]);
  let field-type = map-to-dylan-type(g-field-info-get-type(field));
  // XXX: Check field flags, if not writable, flag as constant.
  // XXX: Consider prefixing the name with the struct name.
  // XXX: Need to export these bindings (field getter and setter), but again,
  //      that should check readable / writable flags.
  format(context.output-stream, "  slot %s :: %s;\n", field-name, field-type);
end function;
