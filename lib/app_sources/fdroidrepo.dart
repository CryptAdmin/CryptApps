import 'package:easy_localization/easy_localization.dart';
import 'package:html/parser.dart';
import 'package:CryptApps/components/generated_form.dart';
import 'package:CryptApps/custom_errors.dart';
import 'package:CryptApps/providers/source_provider.dart';

class FDroidRepo extends AppSource {
  FDroidRepo() {
    name = tr('fdroidThirdPartyRepo');

    additionalSourceAppSpecificSettingFormItems = [
      [
        GeneratedFormTextField('appIdOrName',
            label: tr('appIdOrName'),
            hint: tr('reposHaveMultipleApps'),
            required: true)
      ],
      [
        GeneratedFormSwitch('pickHighestVersionCode',
            label: tr('pickHighestVersionCode'), defaultValue: false)
      ]
    ];
  }

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    String? appIdOrName = additionalSettings['appIdOrName'];
    bool pickHighestVersionCode = additionalSettings['pickHighestVersionCode'];
    if (appIdOrName == null) {
      throw NoReleasesError();
    }
    var res = await sourceRequest('$standardUrl/index.xml');
    if (res.statusCode == 200) {
      var body = parse(res.body);
      var foundApps = body.querySelectorAll('application').where((element) {
        return element.attributes['id'] == appIdOrName;
      }).toList();
      if (foundApps.isEmpty) {
        foundApps = body.querySelectorAll('application').where((element) {
          return element.querySelector('name')?.innerHtml.toLowerCase() ==
              appIdOrName.toLowerCase();
        }).toList();
      }
      if (foundApps.isEmpty) {
        foundApps = body.querySelectorAll('application').where((element) {
          return element
                  .querySelector('name')
                  ?.innerHtml
                  .toLowerCase()
                  .contains(appIdOrName.toLowerCase()) ??
              false;
        }).toList();
      }
      if (foundApps.isEmpty) {
        throw CryptAppsError(tr('appWithIdOrNameNotFound'));
      }
      var authorName = body.querySelector('repo')?.attributes['name'] ?? name;
      var appName =
          foundApps[0].querySelector('name')?.innerHtml ?? appIdOrName;
      var releases = foundApps[0].querySelectorAll('package');
      String? latestVersion = releases[0].querySelector('version')?.innerHtml;
      String? added = releases[0].querySelector('added')?.innerHtml;
      DateTime? releaseDate = added != null ? DateTime.parse(added) : null;
      if (latestVersion == null) {
        throw NoVersionError();
      }
      var latestVersionReleases = releases
          .where((element) =>
              element.querySelector('version')?.innerHtml == latestVersion &&
              element.querySelector('apkname') != null)
          .toList();
      if (latestVersionReleases.length > 1 && pickHighestVersionCode) {
        latestVersionReleases.sort((e1, e2) {
          return int.parse(e2.querySelector('versioncode')!.innerHtml)
              .compareTo(int.parse(e1.querySelector('versioncode')!.innerHtml));
        });
        latestVersionReleases = [latestVersionReleases[0]];
      }
      List<String> apkUrls = latestVersionReleases
          .map((e) => '$standardUrl/${e.querySelector('apkname')!.innerHtml}')
          .toList();
      return APKDetails(latestVersion, getApkUrlsFromUrls(apkUrls),
          AppNames(authorName, appName),
          releaseDate: releaseDate);
    } else {
      throw getCryptAppsHttpError(res);
    }
  }
}
