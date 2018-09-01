import Vue from 'vue'
import element from 'element-ui';
import 'element-ui/lib/theme-chalk/index.css';

import App from './App'

if (!process.env.IS_WEB) Vue.use(require('vue-electron'))
Vue.config.productionTip = false
Vue.use(element);

/* eslint-disable no-new */
new Vue({
  components: { App },
  template: '<App/>'
}).$mount('#app')
