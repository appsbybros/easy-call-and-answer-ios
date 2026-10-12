"""Print one build number above every Easy Call build in App Store Connect (TestFlight workflow).
Reads ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY and never prints key material; only the number goes
to stdout. If App Store Connect cannot be read it prints 1, and the workflow's run-number floor decides."""
import json,os,sys,time,urllib.parse,urllib.request
import jwt
bundle='com.appsbybros.easycall'
def get(path):
    now=int(time.time())
    claims={'iss':''.join(os.environ['ASC_ISSUER_ID'].split()),'iat':now,'exp':now+900,'aud':'appstoreconnect-v1'}
    token=jwt.encode(claims,os.environ['ASC_PRIVATE_KEY'],algorithm='ES256',headers={'kid':''.join(os.environ['ASC_KEY_ID'].split()),'typ':'JWT'})
    request=urllib.request.Request('https://api.appstoreconnect.apple.com/v1'+path,headers={'Authorization':'Bearer '+token})
    with urllib.request.urlopen(request,timeout=60) as response:
        return json.loads(response.read() or b'{}')
try:
    apps=[item['id'] for item in get('/apps?'+urllib.parse.urlencode({'filter[bundleId]':bundle}))['data'] if item['attributes']['bundleId']==bundle]
    query=urllib.parse.urlencode({'filter[app]':apps[0],'sort':'-uploadedDate','limit':200,'fields[builds]':'version'})
    versions=[str(item['attributes'].get('version','')) for item in get('/builds?'+query)['data']]
    highest=max((int(version) for version in versions if version.isdigit()),default=0)
    print(f'Highest build in App Store Connect: {highest}',file=sys.stderr)
except Exception as error:
    print(f'Could not read the earlier builds ({type(error).__name__} {getattr(error,"code","")}); the run-number floor decides.',file=sys.stderr)
    highest=0
print(highest+1)
