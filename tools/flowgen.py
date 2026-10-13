"""Tiny Flow metadata builder: dicts in, correctly ordered XML out."""
from xml.sax.saxutils import escape
NODE_TYPES = {"actionCalls","assignments","decisions","loops","recordCreates","recordDeletes","recordLookups","recordUpdates","screens","subflows","start"}
ELEMENT_TYPES = {"rules","scheduledPaths","variables","formulas","choices","dynamicChoiceSets","collectionChoiceSets","fields","textTemplates","constants"}

def order(parent, keys):
    if parent == "Flow":
        return sorted(keys)
    if parent in NODE_TYPES:
        head = ["description","name","label","locationX","locationY"]
    elif parent in ELEMENT_TYPES:
        head = ["description","name"]
    else:
        head = []
    first = [k for k in head if k in keys]
    return first + sorted(k for k in keys if k not in head)

def to_xml(tag, val, ind=1):
    pad = "    " * ind
    if isinstance(val, list):
        return "".join(to_xml(tag, v, ind) for v in val)
    if isinstance(val, dict):
        inner = "".join(to_xml(k, val[k], ind + 1) for k in order(tag, list(val.keys())))
        return f"{pad}<{tag}>\n{inner}{pad}</{tag}>\n"
    if isinstance(val, bool):
        val = "true" if val else "false"
    return f"{pad}<{tag}>{escape(str(val))}</{tag}>\n"

def flow(d):
    d = dict(d)
    d.setdefault("apiVersion", "62.0")
    d.setdefault("status", "Active")
    d.setdefault("processMetadataValues", [
        {"name": "BuilderType", "value": {"stringValue": "LightningFlowBuilder"}},
        {"name": "CanvasMode", "value": {"stringValue": "AUTO_LAYOUT_CANVAS"}},
        {"name": "OriginBuilderType", "value": {"stringValue": "LightningFlowBuilder"}}])
    body = "".join(to_xml(k, d[k]) for k in order("Flow", list(d.keys())))
    return '<?xml version="1.0" encoding="UTF-8"?>\n<Flow xmlns="http://soap.sforce.com/2006/04/metadata">\n' + body + "</Flow>\n"

# helpers
def node(name, label=None, **kw):
    d = {"name": name, "label": label or name.replace("_", " "), "locationX": 0, "locationY": 0}
    d.update(kw); return d
def to(target): return {"targetReference": target}
def ref(r): return {"elementReference": r}
def s(v): return {"stringValue": v}
def b(v): return {"booleanValue": v}
def n(v): return {"numberValue": v}
def cond(left, op, right): return {"leftValueReference": left, "operator": op, "rightValue": right}
def filt(field, op, value): return {"field": field, "operator": op, "value": value}
def assign(field, value): return {"field": field, "value": value}
def item(target, value, op="Assign"): return {"assignToReference": target, "operator": op, "value": value}
def var(name, dtype, inp=False, out=False, collection=False, obj=None, value=None):
    d = {"name": name, "dataType": dtype, "isCollection": collection, "isInput": inp, "isOutput": out}
    if obj: d["objectType"] = obj
    if value is not None: d["value"] = value
    return d
def formula(name, dtype, expr): return {"name": name, "dataType": dtype, "expression": expr}
