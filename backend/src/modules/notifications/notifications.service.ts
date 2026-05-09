import { supabaseAdmin } from '../../config/db';
import { io } from '../../realtime/socket.server';
import { NotificationType } from '../../types';

/**
 * Payload for sending a notification.
 */
export interface NotificationPayload {
    /** Target user ID (null for broadcast to all users) */
    userId?: string;
    /** Notification title */
    title: string;
    /** Notification body/message */
    body: string;
    /** Type of notification */
    type: NotificationType;
    /** Additional metadata */
    data?: Record<string, unknown>;
}

/**
 * Notification service for managing user notifications.
 * Handles sending notifications via database and real-time Socket.IO.
 */

export const notificationsService = {
    async send(payload: NotificationPayload) {
        // Persist to DB
        const { data, error } = await supabaseAdmin
            .from('notifications')
            .insert({
                user_id: payload.userId ?? null,
                title: payload.title,
                body: payload.body,
                type: payload.type,
                data: payload.data ?? {},
                read: false,
            })
            .select()
            .single();
        if (error) throw new Error(error.message);

        // Real-time push via Socket.IO
        if (payload.userId) {
            io?.to(`user:${payload.userId}`).emit('notification', data);
        } else {
            io?.emit('notification', data); // broadcast
        }

        return data;
    },

    async getUserNotifications(userId: string, unreadOnly = false) {
        let query = supabaseAdmin
            .from('notifications')
            .select('*')
            .or(`user_id.eq.${userId},user_id.is.null`)
            .order('created_at', { ascending: false })
            .limit(50);

        if (unreadOnly) query = query.eq('read', false);

        const { data, error } = await query;
        if (error) throw new Error(error.message);
        return data;
    },

    async markAsRead(notificationId: string, userId: string) {
        const { data, error } = await supabaseAdmin
            .from('notifications')
            .update({ read: true })
            .eq('id', notificationId)
            .eq('user_id', userId)
            .select()
            .single();
        if (error) throw new Error(error.message);
        return data;
    },

    async markAllAsRead(userId: string) {
        const { error } = await supabaseAdmin
            .from('notifications')
            .update({ read: true })
            .eq('user_id', userId)
            .eq('read', false);
        if (error) throw new Error(error.message);
        return { message: 'All notifications marked as read' };
    },
};
