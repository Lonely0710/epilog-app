import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { Doc, Id } from "./_generated/dataModel";

// Helper to check if years match (within 1 year diff) - duplicated from collections.ts if needed, 
// or shared. For now, we just need to get the media by ID.

export const get = query({
    args: { id: v.id("media") },
    handler: async (ctx, args) => {
        // 1. Get Media
        const media = await ctx.db.get(args.id);
        if (!media) return null;

        // 2. Get User (optional, validation)
        const identity = await ctx.auth.getUserIdentity();
        const userId = identity?.tokenIdentifier;

        // 3. Get Collection Status if user is logged in
        let collectionStatus: any = null;
        let collectionId: string = "";

        if (userId) {
            const collection = await ctx.db
                .query("collections")
                .withIndex("by_user_media", (q) =>
                    q.eq("userId", userId).eq("mediaId", media._id)
                )
                .first();

            if (collection) {
                collectionStatus = collection.status;
                collectionId = collection._id;
            }
        }

        // 4. Get Source Info (to construct full object compliant with Dart entity)
        const allSources = await ctx.db
            .query("media_sources")
            .withIndex("by_media", (q) => q.eq("mediaId", media._id))
            .collect();

        let source = allSources[0]; // default to first
        if (allSources.length > 1) {
            if (media.mediaType === "anime") {
                const bgmSource = allSources.find(s => s.sourceType === "bgm");
                if (bgmSource) source = bgmSource;
            } else {
                const tmdbSource = allSources.find(s => s.sourceType === "tmdb");
                if (tmdbSource) source = tmdbSource;
            }
        }

        const sId = source ? source.sourceId : "";
        const sType = source ? source.sourceType : "";
        const sUrl = source ? source.sourceUrl : "";

        return {
            ...media,
            sourceId: sId,
            sourceType: sType,
            sourceUrl: sUrl,
            collectionId: collectionId,
            watchingStatus: collectionStatus,
            isCollected: !!collectionId,
        };
    },
});

export const getBySource = query({
    args: {
        sourceId: v.string(),
        sourceType: v.string(),
    },
    handler: async (ctx, args) => {
        // 1. Find Media Source
        const mediaSource = await ctx.db
            .query("media_sources")
            .withIndex("by_source", (q) =>
                q.eq("sourceType", args.sourceType).eq("sourceId", args.sourceId)
            )
            .first();

        if (!mediaSource) return null;

        // 2. Get Media
        const media = await ctx.db.get(mediaSource.mediaId);
        if (!media) return null;

        // 3. Get User (optional, validation)
        const identity = await ctx.auth.getUserIdentity();
        const userId = identity?.tokenIdentifier;

        // 4. Get Collection Status if user is logged in
        let collectionStatus: any = null;
        let collectionId: string = "";

        if (userId) {
            const collection = await ctx.db
                .query("collections")
                .withIndex("by_user_media", (q) =>
                    q.eq("userId", userId).eq("mediaId", media._id)
                )
                .first();

            if (collection) {
                collectionStatus = collection.status;
                collectionId = collection._id;
            }
        }

        // 5. Get Source Info (to construct full object compliant with Dart entity)
        // We already have mediaSource but getting all might be safer if we want to prioritize or standard logic
        const allSources = await ctx.db
            .query("media_sources")
            .withIndex("by_media", (q) => q.eq("mediaId", media._id))
            .collect();

        let source = allSources[0]; // default to first
        if (allSources.length > 1) {
            if (media.mediaType === "anime") {
                const bgmSource = allSources.find(s => s.sourceType === "bgm");
                if (bgmSource) source = bgmSource;
            } else {
                const tmdbSource = allSources.find(s => s.sourceType === "tmdb");
                if (tmdbSource) source = tmdbSource;
            }
        }

        const sId = source ? source.sourceId : "";
        const sType = source ? source.sourceType : "";
        const sUrl = source ? source.sourceUrl : "";

        return {
            ...media,
            sourceId: sId,
            sourceType: sType,
            sourceUrl: sUrl,
            collectionId: collectionId,
            watchingStatus: collectionStatus,
            isCollected: !!collectionId,
        };
    },
});

export const getMediaSources = query({
    args: { mediaId: v.id("media") },
    handler: async (ctx, args) => {
        const sources = await ctx.db
            .query("media_sources")
            .withIndex("by_media", (q) => q.eq("mediaId", args.mediaId))
            .collect();

        return sources.map(s => ({
            sourceType: s.sourceType,
            sourceId: s.sourceId,
            sourceUrl: s.sourceUrl,
        }));
    },
});

export const ensureMedia = mutation({
    args: {
        sourceType: v.string(),
        sourceId: v.string(),
        sourceUrl: v.string(),
        mediaType: v.string(),
        titleZh: v.string(),
        titleOriginal: v.optional(v.string()),
        releaseDate: v.optional(v.string()),
        duration: v.optional(v.string()),
        year: v.optional(v.string()),
        posterUrl: v.optional(v.string()),
        summary: v.optional(v.string()),
        staffJson: v.optional(v.string()),
        directorsJson: v.optional(v.string()),
        actorsJson: v.optional(v.string()),
        networksJson: v.optional(v.string()),
        ratingDouban: v.optional(v.union(v.number(), v.string())),
        ratingImdb: v.optional(v.union(v.number(), v.string())),
        ratingBangumi: v.optional(v.union(v.number(), v.string())),
        ratingMaoyan: v.optional(v.union(v.number(), v.string())),
    },
    handler: async (ctx, args) => {
        const existingSource = await ctx.db
            .query("media_sources")
            .withIndex("by_source", (q) =>
                q.eq("sourceType", args.sourceType).eq("sourceId", args.sourceId)
            )
            .first();

        if (existingSource) return existingSource.mediaId;

        const parseJsonArray = (value?: string): string[] => {
            if (!value) return [];
            try {
                const parsed = JSON.parse(value);
                return Array.isArray(parsed) ? parsed.map((v) => String(v)) : [];
            } catch {
                return [];
            }
        };

        const parseNumber = (value?: string | number): number | undefined => {
            if (value === undefined || value === null) return undefined;
            if (typeof value === "number") return value;
            const parsed = parseFloat(value);
            return Number.isFinite(parsed) ? parsed : undefined;
        };

        let candidate = await ctx.db
            .query("media")
            .withIndex("by_type_title_zh", (q) =>
                q.eq("mediaType", args.mediaType).eq("titleZh", args.titleZh)
            )
            .first();

        if (!candidate && args.titleOriginal) {
            candidate = await ctx.db
                .query("media")
                .withIndex("by_type_title_original", (q) =>
                    q.eq("mediaType", args.mediaType).eq("titleOriginal", args.titleOriginal!)
                )
                .first();
        }

        let mediaId: Id<"media">;
        if (candidate) {
            mediaId = candidate._id;
        } else {
            const actors = parseJsonArray(args.actorsJson);
            const directors = parseJsonArray(args.directorsJson);

            let staff: Doc<"media">["staff"] | undefined = undefined;
            if (args.staffJson) {
                try {
                    const parsed = JSON.parse(args.staffJson);
                    staff = {
                        info: parsed.info,
                        actors: Array.isArray(parsed.actors) ? parsed.actors.map((v: any) => String(v)) : undefined,
                        directors: Array.isArray(parsed.directors) ? parsed.directors.map((v: any) => String(v)) : undefined,
                    };
                } catch {
                    staff = undefined;
                }
            }

            let networks: Doc<"media">["networks"] = [];
            if (args.networksJson) {
                try {
                    const parsed = JSON.parse(args.networksJson);
                    if (Array.isArray(parsed)) {
                        networks = parsed.map((n: any) => ({
                            name: String(n.name ?? ""),
                            logoUrl: String(n.logoUrl ?? ""),
                        })).filter((n: any) => n.name);
                    }
                } catch {
                    networks = [];
                }
            }

            const ratingDouban = parseNumber(args.ratingDouban);
            const ratingImdb = parseNumber(args.ratingImdb);
            const ratingBangumi = parseNumber(args.ratingBangumi);
            const ratingMaoyan = parseNumber(args.ratingMaoyan);

            mediaId = await ctx.db.insert("media", {
                mediaType: args.mediaType,
                titleZh: args.titleZh,
                titleOriginal: args.titleOriginal,
                releaseDate: args.releaseDate,
                duration: args.duration,
                year: args.year,
                posterUrl: args.posterUrl,
                summary: args.summary,
                staff,
                directors,
                actors,
                networks,
                rating: ratingDouban ?? ratingImdb ?? ratingBangumi ?? ratingMaoyan ?? 0,
                ratingDouban,
                ratingImdb,
                ratingBangumi,
                ratingMaoyan,
            });
        }

        await ctx.db.insert("media_sources", {
            mediaId,
            sourceType: args.sourceType,
            sourceId: args.sourceId,
            sourceUrl: args.sourceUrl,
        });

        return mediaId;
    },
});

const personValidator = v.object({
    name: v.string(),
    nameCn: v.optional(v.string()),
    imageUrl: v.optional(v.string()),
    role: v.optional(v.string()),
    cv: v.optional(v.string()),
    source: v.optional(v.string()),
    episodeCount: v.optional(v.number()),
});

function infoTableFor(mediaType: string): "anime_info" | "tv_info" | "movies_info" {
    if (mediaType === "anime") return "anime_info";
    if (mediaType === "tv") return "tv_info";
    return "movies_info";
}

function isMissingText(value: unknown): boolean {
    if (typeof value !== "string") return true;
    const text = value.trim();
    if (!text) return true;
    return ["未知", "未知标题", "未知日期", "暂无简介", "暂无制作信息", "----", "0分钟"].includes(text);
}

function hasUsableText(value: unknown): value is string {
    return typeof value === "string" && !isMissingText(value);
}

export const updateDetails = mutation({
    args: {
        mediaId: v.id("media"),
        titleZh: v.optional(v.string()),
        titleOriginal: v.optional(v.string()),
        releaseDate: v.optional(v.string()),
        duration: v.optional(v.string()),
        year: v.optional(v.string()),
        posterUrl: v.optional(v.string()),
        summary: v.optional(v.string()),
        staffJson: v.optional(v.string()),
        directorsJson: v.optional(v.string()),
        actorsJson: v.optional(v.string()),
        networksJson: v.optional(v.string()),
        ratingDouban: v.optional(v.union(v.number(), v.string())),
        ratingImdb: v.optional(v.union(v.number(), v.string())),
        ratingBangumi: v.optional(v.union(v.number(), v.string())),
        ratingMaoyan: v.optional(v.union(v.number(), v.string())),
    },
    handler: async (ctx, args) => {
        const existing = await ctx.db.get(args.mediaId);
        if (!existing) throw new Error("Media not found");

        const parseJsonArray = (value?: string): string[] | undefined => {
            if (!value) return undefined;
            try {
                const parsed = JSON.parse(value);
                return Array.isArray(parsed) ? parsed.map((v) => String(v)) : undefined;
            } catch {
                return undefined;
            }
        };

        const parseNumber = (value?: string | number): number | undefined => {
            if (value === undefined || value === null) return undefined;
            if (typeof value === "number") return value;
            const parsed = parseFloat(value);
            return Number.isFinite(parsed) ? parsed : undefined;
        };

        let staff: Doc<"media">["staff"] | undefined = undefined;
        if (args.staffJson) {
            try {
                const parsed = JSON.parse(args.staffJson);
                staff = {
                    info: parsed.info,
                    actors: Array.isArray(parsed.actors) ? parsed.actors.map((v: any) => String(v)) : undefined,
                    directors: Array.isArray(parsed.directors) ? parsed.directors.map((v: any) => String(v)) : undefined,
                };
            } catch {
                staff = undefined;
            }
        }

        let networks: Doc<"media">["networks"] | undefined = undefined;
        if (args.networksJson) {
            try {
                const parsed = JSON.parse(args.networksJson);
                if (Array.isArray(parsed)) {
                    networks = parsed.map((n: any) => ({
                        name: String(n.name ?? ""),
                        logoUrl: String(n.logoUrl ?? ""),
                    })).filter((n: any) => n.name);
                }
            } catch {
                networks = undefined;
            }
        }

        const patch: Partial<Doc<"media">> = {};
        if (isMissingText(existing.titleZh) && hasUsableText(args.titleZh)) patch.titleZh = args.titleZh;
        if (isMissingText(existing.titleOriginal) && hasUsableText(args.titleOriginal)) patch.titleOriginal = args.titleOriginal;
        if (isMissingText(existing.releaseDate) && hasUsableText(args.releaseDate)) patch.releaseDate = args.releaseDate;
        if (isMissingText(existing.duration) && hasUsableText(args.duration)) patch.duration = args.duration;
        if (isMissingText(existing.year) && hasUsableText(args.year)) patch.year = args.year;
        if (isMissingText(existing.posterUrl) && hasUsableText(args.posterUrl)) patch.posterUrl = args.posterUrl;
        if (isMissingText(existing.summary) && hasUsableText(args.summary)) patch.summary = args.summary;
        if (!existing.staff && staff !== undefined) patch.staff = staff;
        const directors = parseJsonArray(args.directorsJson);
        const actors = parseJsonArray(args.actorsJson);
        if ((!existing.directors || existing.directors.length === 0) && directors !== undefined && directors.length > 0) patch.directors = directors;
        if ((!existing.actors || existing.actors.length === 0) && actors !== undefined && actors.length > 0) patch.actors = actors;
        if ((!existing.networks || existing.networks.length === 0) && networks !== undefined && networks.length > 0) patch.networks = networks;

        const ratingDouban = parseNumber(args.ratingDouban);
        const ratingImdb = parseNumber(args.ratingImdb);
        const ratingBangumi = parseNumber(args.ratingBangumi);
        const ratingMaoyan = parseNumber(args.ratingMaoyan);
        if ((!existing.ratingDouban || existing.ratingDouban <= 0) && ratingDouban !== undefined && ratingDouban > 0) patch.ratingDouban = ratingDouban;
        if ((!existing.ratingImdb || existing.ratingImdb <= 0) && ratingImdb !== undefined && ratingImdb > 0) patch.ratingImdb = ratingImdb;
        if ((!existing.ratingBangumi || existing.ratingBangumi <= 0) && ratingBangumi !== undefined && ratingBangumi > 0) patch.ratingBangumi = ratingBangumi;
        if ((!existing.ratingMaoyan || existing.ratingMaoyan <= 0) && ratingMaoyan !== undefined && ratingMaoyan > 0) patch.ratingMaoyan = ratingMaoyan;

        const bestRating = ratingDouban ?? ratingImdb ?? ratingBangumi ?? ratingMaoyan;
        if ((!existing.rating || existing.rating <= 0) && bestRating !== undefined && bestRating > 0) patch.rating = bestRating;

        await ctx.db.patch(args.mediaId, patch);
        return { success: true };
    },
});

export const getInfo = query({
    args: {
        mediaId: v.id("media"),
        mediaType: v.string(),
    },
    handler: async (ctx, args) => {
        const table = infoTableFor(args.mediaType);
        return await ctx.db
            .query(table)
            .withIndex("by_media", (q) => q.eq("mediaId", args.mediaId))
            .first();
    },
});

export const upsertInfo = mutation({
    args: {
        mediaId: v.id("media"),
        mediaType: v.string(),
        people: v.optional(v.array(personValidator)),
        peopleJson: v.optional(v.string()),
    },
    handler: async (ctx, args) => {
        const table = infoTableFor(args.mediaType);
        let people = args.people ?? [];
        if (args.peopleJson) {
            try {
                const parsed = JSON.parse(args.peopleJson);
                if (Array.isArray(parsed)) {
                    people = parsed.map((person: any) => ({
                        name: String(person.name ?? ""),
                        nameCn: person.nameCn ? String(person.nameCn) : undefined,
                        imageUrl: person.imageUrl ? String(person.imageUrl) : undefined,
                        role: person.role ? String(person.role) : undefined,
                        cv: person.cv ? String(person.cv) : undefined,
                        source: person.source ? String(person.source) : undefined,
                        episodeCount: typeof person.episodeCount === "number" ? person.episodeCount : undefined,
                    })).filter((person: any) => person.name);
                }
            } catch {
                people = args.people ?? [];
            }
        }

        const existing = await ctx.db
            .query(table)
            .withIndex("by_media", (q) => q.eq("mediaId", args.mediaId))
            .first();

        const patch = {
            mediaId: args.mediaId as Id<"media">,
            people,
            updatedAt: Date.now(),
        };

        if (existing) {
            await ctx.db.patch(existing._id, patch);
            return existing._id;
        }

        return await ctx.db.insert(table, patch);
    },
});
