"use node";
import { v } from "convex/values";
import { action } from "./_generated/server";

export const proxy = action({
    args: {
        path: v.string(),
        query: v.optional(v.any()), // Map of query params
        method: v.optional(v.string()),
        body: v.optional(v.any()),
    },
    handler: async (ctx, args) => {
        const tmdbToken = process.env.TMDB_ACCESS_TOKEN;
        if (!tmdbToken) {
            throw new Error("TMDB_ACCESS_TOKEN is not set in Convex environment variables.");
        }

        const TMDB_BASE_URL = "https://api.themoviedb.org/3";
        const targetUrlObject = new URL(`${TMDB_BASE_URL}${args.path}`);

        if (args.query) {
            let queryObj = args.query;

            // Handle case where query is passed as a string (JSON)
            if (typeof queryObj === 'string') {
                try {
                    queryObj = JSON.parse(queryObj);
                } catch (e) {
                    console.error("Failed to parse query string:", e);
                    // Fallback to empty object or handle as needed
                    queryObj = {};
                }
            }

            console.log(`[TMDB Proxy] Processing query params:`, queryObj);

            // Ensure language is set to zh-CN if not provided
            if (!queryObj['language']) {
                queryObj['language'] = 'zh-CN';
            }

            for (const [key, value] of Object.entries(queryObj)) {
                if (value !== undefined && value !== null) {
                    targetUrlObject.searchParams.set(key, String(value));
                }
            }
        } else {
            if (!targetUrlObject.searchParams.has('language')) {
                targetUrlObject.searchParams.set('language', 'zh-CN');
            }
        }

        const targetUrl = targetUrlObject.toString();
        console.log(`Forwarding request to: ${targetUrl}`);

        const response = await fetch(targetUrl, {
            method: args.method || "GET",
            headers: {
                Authorization: `Bearer ${tmdbToken}`,
                "Content-Type": "application/json",
                Accept: "application/json",
            },
            body: args.body ? JSON.stringify(args.body) : undefined,
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`TMDB API Error: ${response.status} ${errorText}`);
            throw new Error(`TMDB API Error: ${response.status}`);
        }

        return await response.json();
    },
});
