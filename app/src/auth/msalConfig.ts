import { Configuration, LogLevel } from '@azure/msal-browser';

// authority = https://<xid-host>/<tenant> (local: http://localhost:8787/common)
// XID expone facade Entra: /{tenant}/oauth2/v2.0/authorize, /token, /.well-known/openid-configuration
export const msalConfig: Configuration = {
  auth: {
    clientId: import.meta.env.VITE_XID_CLIENT_ID ?? 'my-webapp',
    authority: import.meta.env.VITE_XID_AUTHORITY ?? 'http://localhost:8787/common',
    redirectUri: window.location.origin + '/',
    postLogoutRedirectUri: window.location.origin + '/'
  },
  cache: {
    cacheLocation: 'sessionStorage',
    storeAuthStateInCookie: false
  },
  system: {
    loggerOptions: {
      logLevel: LogLevel.Warning,
      loggerCallback: (level, message) => {
        if (level <= LogLevel.Warning) console.log(`[msal] ${message}`);
      }
    }
  }
};

export const loginRequest = {
  scopes: [
    'openid',
    'profile',
    (import.meta.env.VITE_XDB_API_SCOPE as string) ?? 'api://my-webapp/access_as_user'
  ]
};
