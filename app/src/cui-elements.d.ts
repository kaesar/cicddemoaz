// Declaraciones para los web components OnMind-CUI v3 (vendorizado en public/cui/).
// Se manipulan vía atributos y listeners nativos (ver App.tsx); aquí solo los tipos JSX.
import type * as React from 'react';

declare global {
  namespace JSX {
    interface IntrinsicElements {
      'as-button': React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement> & {
        label?: string;
        variant?: 'primary' | 'secondary';
        link?: string;
        message?: string;
        disabled?: boolean | string;
      };
      'as-box': React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement> & {
        dim?: string;
        theme?: string;
      };
      'as-datagrid': React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement> & {
        title?: string;
        pageSize?: string | number;
        selectable?: boolean;
        pageable?: boolean;
        filterable?: boolean;
        actionable?: boolean;
      };
    }
  }
}

export {};
