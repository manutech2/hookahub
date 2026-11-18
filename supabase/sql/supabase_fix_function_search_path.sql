-- Mitigación para el warning "Function Search Path Mutable"
-- Añadimos explícitamente "SET search_path = public" a todas las funciones SECURITY DEFINER
-- para evitar posibles ataques de inyección y escalada de privilegios.

ALTER FUNCTION public.clean_old_mix_views(integer) SET search_path = public;
ALTER FUNCTION public.update_tobacco_rating() SET search_path = public;
ALTER FUNCTION public.update_tobacco_rating_on_delete() SET search_path = public;
ALTER FUNCTION public.create_notification(uuid, text, jsonb) SET search_path = public;
ALTER FUNCTION public.notify_review_on_mix() SET search_path = public;
ALTER FUNCTION public.notify_new_tobacco() SET search_path = public;
ALTER FUNCTION public.notify_favorite_on_mix() SET search_path = public;
ALTER FUNCTION public.notify_trending_mix() SET search_path = public;
