<script>
import { useBranding } from 'shared/composables/useBranding';

const {
  LOGO_THUMBNAIL: logoThumbnail,
  BRAND_NAME: brandName,
  WIDGET_BRAND_URL: widgetBrandURL,
} = window.globalConfig || {};

const toHttpURL = value => {
  try {
    const url = new URL(value);
    return ['http:', 'https:'].includes(url.protocol) ? url.toString() : '';
  } catch (e) {
    return '';
  }
};

export default {
  props: {
    disableBranding: {
      type: Boolean,
      default: false,
    },
    // Per-inbox footer customization: { text, logoUrl, url }. When it is
    // passed, the footer only links to its own url and never to the
    // installation brand site.
    branding: {
      type: Object,
      default: null,
    },
  },
  setup() {
    const { replaceInstallationName } = useBranding();
    return {
      replaceInstallationName,
    };
  },
  data() {
    return {
      globalConfig: {
        brandName,
        logoThumbnail,
        widgetBrandURL,
      },
    };
  },
  computed: {
    showBranding() {
      if (this.disableBranding) return false;
      return Boolean(this.globalConfig.brandName || this.branding?.text);
    },
    brandText() {
      return (
        this.branding?.text ||
        this.replaceInstallationName(this.$t('POWERED_BY'))
      );
    },
    brandLogo() {
      return this.branding?.logoUrl || this.globalConfig.logoThumbnail;
    },
    brandAlt() {
      return this.branding?.text || this.globalConfig.brandName;
    },
    linkURL() {
      if (this.branding) return toHttpURL(this.branding.url);
      return this.brandRedirectURL;
    },
    linkAttrs() {
      if (!this.linkURL) return {};
      return {
        href: this.linkURL,
        rel: 'noreferrer noopener nofollow',
        target: '_blank',
      };
    },
    linkClasses() {
      return {
        'cursor-pointer hover:text-n-slate-12 hover:opacity-100': this.linkURL,
        'grayscale-[1]': !this.branding?.logoUrl,
        'hover:grayscale-0': this.linkURL && !this.branding?.logoUrl,
      };
    },
    logoClasses() {
      return this.branding?.logoUrl
        ? 'max-w-16 max-h-4 object-contain'
        : 'max-w-3 max-h-3';
    },
    brandRedirectURL() {
      try {
        const referrerHost = this.$store.getters['appConfig/getReferrerHost'];
        const url = new URL(this.globalConfig.widgetBrandURL);
        if (referrerHost) {
          url.searchParams.set('utm_source', referrerHost);
          url.searchParams.set('utm_medium', 'widget');
        } else {
          url.searchParams.set('utm_medium', 'survey');
        }
        url.searchParams.set('utm_campaign', 'branding');
        return url.toString();
      } catch (e) {
        // Suppressing the error as getter is not defined in some cases
      }
      return '';
    },
  },
};
</script>

<template>
  <div v-if="showBranding" class="px-0 py-3 flex justify-center">
    <component
      :is="linkURL ? 'a' : 'span'"
      v-bind="linkAttrs"
      class="branding--link text-n-slate-11 text-xs inline-flex opacity-90 no-underline justify-center items-center leading-3"
      :class="linkClasses"
    >
      <img
        v-if="brandLogo"
        class="ltr:mr-1 rtl:ml-1"
        :class="logoClasses"
        :alt="brandAlt"
        :src="brandLogo"
      />
      <span>
        {{ brandText }}
      </span>
    </component>
  </div>
  <div v-else class="p-3" />
</template>
