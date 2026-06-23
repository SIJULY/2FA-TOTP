function getCurrentSeconds() {
  return Math.round(new Date().getTime() / 1000.0);
}

function stripSpaces(str) {
  return str.replace(/\s/g, '');
}

function truncateTo(str, digits) {
  if (str.length <= digits) {
    return str;
  }

  return str.slice(-digits);
}

function parseURLSearch(search) {
  const queryParams = search.substr(1).split('&').reduce(function (q, query) {
    const chunks = query.split('=');
    const key = chunks[0];
    let value = decodeURIComponent(chunks[1]);
    value = isNaN(Number(value)) ? value : Number(value);
    return (q[key] = value, q);
  }, {});

  return queryParams;
}

new Vue({
  el: '#app',
  data: {
    secret_key: 'JBSWY3DPEHPK3PXP',
    digits: 6,
    period: 30,
    updatingIn: 30,
    token: null,
    clipboardButton: null,
    showToast: false
  },

  mounted: function () {
    this.getKeyFromUrl();
    this.getQueryParameters()
    this.update();

    this.intervalHandle = setInterval(this.update, 1000);

    this.clipboardButton = new ClipboardJS('#clipboard-button');
    
    // 监听复制成功事件，显示原生的 Toast 提示，并防止选中文字
    const self = this;
    this.clipboardButton.on('success', function(e) {
      e.clearSelection(); // 清除选中状态，避免出现选中文本背景色和菜单
      
      self.showToast = true;
      setTimeout(function() {
        self.showToast = false;
      }, 2000); // 2秒后消失
    });
  },

  destroyed: function () {
    clearInterval(this.intervalHandle);
  },

  computed: {
    totp: function () {
      try {
        return new OTPAuth.TOTP({
          algorithm: 'SHA1',
          digits: this.digits,
          period: this.period,
          secret: OTPAuth.Secret.fromB32(stripSpaces(this.secret_key)),
        });
      } catch (e) {
        // 如果秘钥无效，返回一个假的 TOTP 对象避免报错
        return { generate: () => "------" };
      }
    }
  },

  methods: {
    update: function () {
      this.updatingIn = this.period - (getCurrentSeconds() % this.period);
      this.token = truncateTo(this.totp.generate(), this.digits);
    },

    getKeyFromUrl: function () {
      const key = document.location.hash.replace(/[#\/]+/, '');

      if (key.length > 0) {
        this.secret_key = key;
      }
    },
    getQueryParameters: function () {
      if (!window.location.search) return;
      
      const queryParams = parseURLSearch(window.location.search);

      if (queryParams.key) {
        this.secret_key = queryParams.key;
      }

      if (queryParams.digits) {
        this.digits = queryParams.digits;
      }

      if (queryParams.period) {
        this.period = queryParams.period;
      }
    }
  }
});