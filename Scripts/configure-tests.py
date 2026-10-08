"""Connect the local StoreKit test plan to XcodeGen's generated target identifiers."""
from pathlib import Path
import json,xml.etree.ElementTree as ET
scheme=Path('EasyCall.xcodeproj/xcshareddata/xcschemes/EasyCall.xcscheme')
tree=ET.parse(scheme);root=tree.getroot();action=root.find('TestAction')
def reference(element):
    return {'containerPath':element.get('ReferencedContainer'),'identifier':element.get('BlueprintIdentifier'),'name':element.get('BlueprintName')}
targets=[{'parallelizable':False,'target':reference(item)} for item in action.findall('./Testables/TestableReference/BuildableReference')]
app=root.find('./LaunchAction/BuildableProductRunnable/BuildableReference')
plan={'configurations':[{'id':'B89E5F83-4078-47AD-B5B6-C922D24437C7','name':'Local verification','options':{}}],
      'defaultOptions':{'storeKitConfiguration':{'identifier':'Tests/Hosted/EasyCall.storekit'},'targetForVariableExpansion':reference(app)},
      'testTargets':targets,'version':1}
assert len(targets)==2 and app is not None
Path('EasyCall.xctestplan').write_text(json.dumps(plan,indent=2))
for previous in action.findall('TestPlans'):action.remove(previous)
plans=ET.SubElement(action,'TestPlans')
ET.SubElement(plans,'TestPlanReference',{'reference':'container:EasyCall.xctestplan','default':'YES'})
tree.write(scheme,encoding='utf-8',xml_declaration=True)
print('Configured local StoreKit test plan for both test targets.')
