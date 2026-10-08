"""Install and validate explicitly provided signing assets; never print key material."""
import os,sys,base64,plistlib,subprocess,hashlib,shutil,datetime,re
from pathlib import Path
temp=Path(os.environ['RUNNER_TEMP'])
key_id=os.environ.get('ASC_KEY_ID','')
bundle='com.appsbybros.easycall'
def write_private(path,data):
    path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);path.chmod(0o600)
if sys.argv[1]=='prepare':
    assert re.fullmatch(r'[A-Z0-9]{10}',key_id),'Check ASC_KEY_ID.'
    for name,filename in [('DISTRIBUTION_P12_BASE64','distribution.p12'),('PROVISION_PROFILE_BASE64','profile.mobileprovision')]:
        write_private(temp/filename,base64.b64decode(''.join(os.environ[name].split()),validate=True))
    write_private(Path.home()/'.appstoreconnect/private_keys'/f'AuthKey_{key_id}.p8',os.environ['ASC_PRIVATE_KEY'].encode())
elif sys.argv[1]=='validate':
    profile=plistlib.loads((temp/'profile.plist').read_bytes())
    team=profile['TeamIdentifier'][0];uuid=profile['UUID'];entitlements=profile['Entitlements']
    assert entitlements['application-identifier'].endswith('.'+bundle),'Profile is for a different app.'
    assert not entitlements.get('get-task-allow',False),'Use an App Store distribution profile, not Development.'
    assert not profile.get('ProvisionedDevices') and not profile.get('ProvisionsAllDevices'),'Use an App Store profile, not Ad Hoc or Enterprise.'
    assert profile['ExpirationDate']>datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None),'Provisioning profile has expired.'
    identities=subprocess.check_output(['security','find-identity','-v','-p','codesigning',str(temp/'easycall.keychain-db')],text=True)
    matching=[hashlib.sha1(cert).hexdigest().upper() for cert in profile['DeveloperCertificates'] if hashlib.sha1(cert).hexdigest().upper() in identities]
    assert matching,'No private signing key matching this provisioning profile was imported.'
    destination=Path.home()/'Library/MobileDevice/Provisioning Profiles'/f'{uuid}.mobileprovision'
    write_private(destination,(temp/'profile.mobileprovision').read_bytes())
    write_private(temp/'installed-profile-path.txt',str(destination).encode())
    with open(os.environ['GITHUB_ENV'],'a') as stream:
        stream.write(f'SIGNING_TEAM={team}\nPROFILE_UUID={uuid}\nSIGNING_IDENTITY={matching[0]}\n')
    export={'method':'app-store-connect','destination':'export','signingStyle':'manual','teamID':team,'signingCertificate':matching[0],'provisioningProfiles':{bundle:uuid},'manageAppVersionAndBuildNumber':False,'stripSwiftSymbols':True}
    write_private(temp/'ExportOptions.plist',plistlib.dumps(export))
    print('Distribution profile, expiry, app identifier and private signing identity verified.')
elif sys.argv[1]=='clean':
    marker=temp/'installed-profile-path.txt'
    if marker.exists():
        target=Path(marker.read_text())
        expected=Path.home()/'Library/MobileDevice/Provisioning Profiles'
        if target.parent==expected:target.unlink(missing_ok=True)
    if re.fullmatch(r'[A-Z0-9]{10}',key_id):
        (Path.home()/'.appstoreconnect/private_keys'/f'AuthKey_{key_id}.p8').unlink(missing_ok=True)
    for name in ('distribution.p12','profile.mobileprovision','profile.plist','ExportOptions.plist','installed-profile-path.txt'):
        (temp/name).unlink(missing_ok=True)
