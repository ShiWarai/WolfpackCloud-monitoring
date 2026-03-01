import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/pages/LoginPage.vue'),
      meta: { requiresGuest: true },
    },
    // Регистрация отключена. Используется единственный аккаунт администратора.
    // {
    //   path: '/register',
    //   name: 'register',
    //   component: () => import('@/pages/RegisterPage.vue'),
    //   meta: { requiresGuest: true },
    // },
    {
      path: '/',
      redirect: '/dashboard',
    },
    {
      path: '/dashboard',
      name: 'dashboard',
      component: () => import('@/pages/DashboardPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/robots',
      name: 'robots',
      component: () => import('@/pages/RobotsPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/robots/:id',
      name: 'robot-detail',
      component: () => import('@/pages/RobotDetailPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/pairing',
      name: 'pairing',
      component: () => import('@/pages/PairingPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/dashboard',
    },
  ],
})

let initialized = false

router.beforeEach(async (to, _from, next) => {
  const authStore = useAuthStore()

  if (!initialized) {
    await authStore.init()
    initialized = true
  }

  const isAuthenticated = authStore.isAuthenticated

  if (to.meta.requiresAuth && !isAuthenticated) {
    next({ name: 'login', query: { redirect: to.fullPath } })
  } else if (to.meta.requiresGuest && isAuthenticated) {
    next({ name: 'dashboard' })
  } else {
    next()
  }
})

export default router
