import { withPluginApi } from "discourse/lib/plugin-api";
import I18n from "I18n";

export default {
  name: "setup-pfaffmanager-servers",
  initialize(container) {
    withPluginApi("0.8.11", (api) => {
      const siteSettings = container.lookup("site-settings:main");
      // TODO: do not display link if not logged in
      const isNavLinkEnabled = siteSettings.pfaffmanager_enabled;
      if (isNavLinkEnabled) {
        api.addNavigationBarItem({
          name: "servers",
          displayName: I18n.t("pfaffmanager.server.navigation_link"),
          href: "/pfaffmanager/servers",
        });
      }
    });
  },
};
