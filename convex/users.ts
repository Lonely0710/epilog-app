import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

/**
 * Store or update user profile
 */
export const storeUser = mutation({
    args: {
        name: v.optional(v.string()),
        avatarStorageId: v.optional(v.string()), // Storage ID from upload
    },
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) {
            return {
                ok: false,
                code: "UNAUTHENTICATED",
                message: "Convex auth identity is missing.",
            };
        }

        // Check if we have an existing user
        const user = await ctx.db
            .query("users")
            .withIndex("by_token", (q) => q.eq("tokenIdentifier", identity.tokenIdentifier))
            .unique();

        let avatarUrl: string | undefined;
        if (args.avatarStorageId) {
            // Generate a URL for the uploaded file
            // NOTE: This URL is ephemeral or permanent depending on Convex config, 
            // typically storage URLs are valid.
            const url = await ctx.storage.getUrl(args.avatarStorageId);
            if (url) {
                avatarUrl = url;
            }
        }

        if (user !== null) {
            // Update existing user
            await ctx.db.patch(user._id, {
                ...(args.name ? { name: args.name } : {}),
                // Only update avatar if a new one was provided, otherwise keep existing
                ...(avatarUrl ? { avatarUrl } : {}),
            });
            return {
                ok: true,
                userId: user._id,
                avatarUrl: avatarUrl ?? user.avatarUrl,
            };
        } else {
            // Create new user
            const newUserId = await ctx.db.insert("users", {
                tokenIdentifier: identity.tokenIdentifier,
                name: args.name,
                avatarUrl: avatarUrl,
            });
            return {
                ok: true,
                userId: newUserId,
                avatarUrl,
            };
        }
    },
});

/**
 * Generate a URL for uploading a file to Convex Storage
 */
export const generateUploadUrl = mutation({
    args: {},
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) {
            return null;
        }
        return await ctx.storage.generateUploadUrl();
    },
});

/**
 * Debug the auth identity Convex sees for the current request.
 */
export const authStatus = query({
    args: {},
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) {
            return { isAuthenticated: false };
        }

        return {
            isAuthenticated: true,
            issuer: identity.issuer,
            subject: identity.subject,
            tokenIdentifier: identity.tokenIdentifier,
        };
    },
});

/**
 * Get current user profile
 */
export const currentUser = query({
    args: {},
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) {
            return null;
        }
        return await ctx.db
            .query("users")
            .withIndex("by_token", (q) => q.eq("tokenIdentifier", identity.tokenIdentifier))
            .unique();
    },
});

/**
 * Delete all app data owned by the current authenticated user.
 */
export const deleteCurrentUserData = mutation({
    args: {},
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) {
            return {
                ok: false,
                code: "UNAUTHENTICATED",
                message: "Convex auth identity is missing.",
            };
        }

        const tokenIdentifier = identity.tokenIdentifier;
        const collections = await ctx.db
            .query("collections")
            .withIndex("by_user", (q) => q.eq("userId", tokenIdentifier))
            .collect();

        for (const collection of collections) {
            await ctx.db.delete(collection._id);
        }

        const user = await ctx.db
            .query("users")
            .withIndex("by_token", (q) => q.eq("tokenIdentifier", tokenIdentifier))
            .unique();

        if (user) {
            await ctx.db.delete(user._id);
        }

        return {
            ok: true,
            deletedCollections: collections.length,
            deletedUser: user !== null,
        };
    },
});
