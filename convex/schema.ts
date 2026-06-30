import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
    users: defineTable({
        tokenIdentifier: v.string(), // Unique ID from auth provider
        name: v.optional(v.string()),
        avatarUrl: v.optional(v.string()),
    }).index("by_token", ["tokenIdentifier"]),

    media: defineTable({
        // Content Fields (Deduplicated)
        mediaType: v.string(), // movie, tv, anime
        titleZh: v.string(),
        titleOriginal: v.optional(v.string()),
        releaseDate: v.optional(v.string()),
        duration: v.optional(v.string()),
        year: v.optional(v.string()),
        posterUrl: v.optional(v.string()),
        summary: v.optional(v.string()),
        staff: v.optional(v.object({
            info: v.optional(v.string()),
            actors: v.optional(v.array(v.string())),
            directors: v.optional(v.array(v.string())),
        })),
        directors: v.optional(v.array(v.string())),
        actors: v.optional(v.array(v.string())),
        networks: v.optional(v.array(v.object({
            name: v.string(),
            logoUrl: v.string(),
        }))),


        // Ratings (Aggregated or Latest)
        rating: v.number(),
        ratingDouban: v.optional(v.number()),
        ratingImdb: v.optional(v.number()),
        ratingBangumi: v.optional(v.number()),
        ratingMaoyan: v.optional(v.number()),
    })
        .index("by_type_title_zh", ["mediaType", "titleZh"]) // For fuzzy matching
        .index("by_type_title_original", ["mediaType", "titleOriginal"]), // For fuzzy matching

    media_sources: defineTable({
        mediaId: v.id("media"),
        sourceType: v.string(), // tmdb, bgm, douban, maoyan
        sourceId: v.string(),
        sourceUrl: v.string(),
    })
        .index("by_source", ["sourceType", "sourceId"])
        .index("by_media", ["mediaId"]),

    collections: defineTable({
        userId: v.string(), // referencing users.tokenIdentifier
        mediaId: v.id("media"),
        status: v.string(), // wish, watching, watched, on_hold, dropped
        createdAt: v.number(),
        updatedAt: v.number(),
    })
        .index("by_user", ["userId"])
        .index("by_user_media", ["userId", "mediaId"])
        .index("by_user_created", ["userId", "createdAt"]),

    anime_info: defineTable({
        mediaId: v.id("media"),
        people: v.array(v.object({
            name: v.string(),
            nameCn: v.optional(v.string()),
            imageUrl: v.optional(v.string()),
            role: v.optional(v.string()),
            cv: v.optional(v.string()),
            source: v.optional(v.string()),
            episodeCount: v.optional(v.number()),
        })),
        updatedAt: v.number(),
    }).index("by_media", ["mediaId"]),

    tv_info: defineTable({
        mediaId: v.id("media"),
        people: v.array(v.object({
            name: v.string(),
            nameCn: v.optional(v.string()),
            imageUrl: v.optional(v.string()),
            role: v.optional(v.string()),
            cv: v.optional(v.string()),
            source: v.optional(v.string()),
            episodeCount: v.optional(v.number()),
        })),
        updatedAt: v.number(),
    }).index("by_media", ["mediaId"]),

    movies_info: defineTable({
        mediaId: v.id("media"),
        people: v.array(v.object({
            name: v.string(),
            nameCn: v.optional(v.string()),
            imageUrl: v.optional(v.string()),
            role: v.optional(v.string()),
            cv: v.optional(v.string()),
            source: v.optional(v.string()),
            episodeCount: v.optional(v.number()),
        })),
        updatedAt: v.number(),
    }).index("by_media", ["mediaId"]),
});
