const std = @import("std");
const testing = std.testing;
const c = @cImport({
    @cInclude("joltc.h");
});

fn on_contact_validate(
    _: ?*anyopaque,
    _: ?*const c.JPH_Body,
    _: ?*const c.JPH_Body,
    _: [*c]const c.JPH_RVec3,
    _: [*c]const c.JPH_CollideShapeResult,
) callconv(.c) c.JPH_ValidateResult {
    std.debug.print("[ContactListener] Contact validate callback\n", .{});
    return c.JPH_ValidateResult_AcceptAllContactsForThisBodyPair;
}

fn on_contact_added(
    _: ?*anyopaque,
    _: ?*const c.JPH_Body,
    _: ?*const c.JPH_Body,
    _: ?*const c.JPH_ContactManifold,
    _: [*c]c.JPH_ContactSettings,
) callconv(.c) void {
    std.debug.print("[ContactListener] A contact was added\n", .{});
}

fn on_contact_persisted(
    _: ?*anyopaque,
    _: ?*const c.JPH_Body,
    _: ?*const c.JPH_Body,
    _: ?*const c.JPH_ContactManifold,
    _: [*c]c.JPH_ContactSettings,
) callconv(.c) void {
    std.debug.print("[ContactListener] A contact was persisted\n", .{});
}

fn on_contact_removed(
    _: ?*anyopaque,
    _: [*c]const c.JPH_SubShapeIDPair,
) callconv(.c) void {
    std.debug.print("[ContactListener] A contact was removed\n", .{});
}

fn on_body_activated(
    _: ?*anyopaque,
    _: c.JPH_BodyID,
    _: u64,
) callconv(.c) void {
    std.debug.print("[BodyActivationListener] A body for activated\n", .{});
}
fn on_body_deactivated(
    _: ?*anyopaque,
    _: c.JPH_BodyID,
    _: u64,
) callconv(.c) void {
    std.debug.print("[BodyActivationListener] A body went to sleep\n", .{});
}

test "hello world" {
    const OBJECT_LAYER_NON_MOVING: c.JPH_ObjectLayer = 0;
    const OBJECT_LAYER_MOVING: c.JPH_ObjectLayer = 1;
    const OBJECT_LAYER_NUM = 2;

    const BROAD_PHASE_LAYER_NON_MOVING: c.JPH_BroadPhaseLayer = 0;
    const BROAD_PHASE_LAYER_MOVING: c.JPH_BroadPhaseLayer = 1;
    const BROAD_PHASE_NUM = 2;

    try testing.expect(c.JPH_Init());
    defer c.JPH_Shutdown();

    const job_system = c.JPH_JobSystemThreadPool_Create(null);
    try testing.expect(job_system != null);
    defer c.JPH_JobSystem_Destroy(job_system);

    const object_layer_pair_filter = c.JPH_ObjectLayerPairFilterTable_Create(OBJECT_LAYER_NUM);
    c.JPH_ObjectLayerPairFilterTable_EnableCollision(
        object_layer_pair_filter,
        OBJECT_LAYER_MOVING,
        OBJECT_LAYER_MOVING,
    );
    c.JPH_ObjectLayerPairFilterTable_EnableCollision(
        object_layer_pair_filter,
        OBJECT_LAYER_MOVING,
        OBJECT_LAYER_NON_MOVING,
    );

    const broad_phase_layer_interface_table = c.JPH_BroadPhaseLayerInterfaceTable_Create(OBJECT_LAYER_NUM, BROAD_PHASE_NUM);
    c.JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(
        broad_phase_layer_interface_table,
        OBJECT_LAYER_MOVING,
        BROAD_PHASE_LAYER_MOVING,
    );
    c.JPH_BroadPhaseLayerInterfaceTable_MapObjectToBroadPhaseLayer(
        broad_phase_layer_interface_table,
        OBJECT_LAYER_NON_MOVING,
        BROAD_PHASE_LAYER_NON_MOVING,
    );

    const object_vs_broad_phase_layer_filter = c.JPH_ObjectVsBroadPhaseLayerFilterTable_Create(
        broad_phase_layer_interface_table,
        BROAD_PHASE_NUM,
        object_layer_pair_filter,
        OBJECT_LAYER_NUM,
    );

    const physics_system_settings = c.JPH_PhysicsSystemSettings{
        .maxBodies = 1024,
        .numBodyMutexes = 0,
        .maxBodyPairs = 1024,
        .maxContactConstraints = 1024,
        .broadPhaseLayerInterface = broad_phase_layer_interface_table,
        .objectLayerPairFilter = object_layer_pair_filter,
        .objectVsBroadPhaseLayerFilter = object_vs_broad_phase_layer_filter,
    };
    const physics_system = c.JPH_PhysicsSystem_Create(&physics_system_settings);
    try testing.expect(physics_system != null);
    defer c.JPH_PhysicsSystem_Destroy(physics_system);

    const my_contact_listener_procs = c.JPH_ContactListener_Procs{
        .OnContactValidate = on_contact_validate,
        .OnContactAdded = on_contact_added,
        .OnContactPersisted = on_contact_persisted,
        .OnContactRemoved = on_contact_removed,
    };
    const my_contact_listener = c.JPH_ContactListener_Create(null);
    c.JPH_ContactListener_SetProcs(&my_contact_listener_procs);
    defer c.JPH_ContactListener_Destroy(my_contact_listener);
    c.JPH_PhysicsSystem_SetContactListener(physics_system, my_contact_listener);

    const my_activation_listener_procs = c.JPH_BodyActivationListener_Procs{
        .OnBodyActivated = on_body_activated,
        .OnBodyDeactivated = on_body_deactivated,
    };
    const my_activation_listener = c.JPH_BodyActivationListener_Create(null);
    c.JPH_BodyActivationListener_SetProcs(&my_activation_listener_procs);
    c.JPH_PhysicsSystem_SetBodyActivationListener(physics_system, my_activation_listener);

    const body_interface = c.JPH_PhysicsSystem_GetBodyInterface(physics_system);

    var floor_id: c.JPH_BodyID = undefined;
    {
        const box_half_extents = c.JPH_Vec3{
            .x = 100,
            .y = 1,
            .z = 100,
        };
        const floor_shape = c.JPH_BoxShape_Create(&box_half_extents, c.JPH_DEFAULT_CONVEX_RADIUS);
        const floor_pos = c.JPH_Vec3{
            .x = 0,
            .y = -1,
            .z = 0,
        };
        const floor_settings = c.JPH_BodyCreationSettings_Create3(
            @ptrCast(floor_shape),
            &floor_pos,
            null,
            c.JPH_MotionType_Static,
            OBJECT_LAYER_NON_MOVING,
        );
        defer c.JPH_BodyCreationSettings_Destroy(floor_settings);
        floor_id = c.JPH_BodyInterface_CreateAndAddBody(
            body_interface,
            floor_settings,
            c.JPH_Activation_DontActivate,
        );
    }
    defer c.JPH_BodyInterface_RemoveAndDestroyBody(body_interface, floor_id);

    var sphere_id: c.JPH_BodyID = undefined;
    {
        const sphere_shape = c.JPH_SphereShape_Create(0.5);
        const sphere_pos = c.JPH_Vec3{
            .x = 0,
            .y = 2,
            .z = 0,
        };
        const sphere_settings = c.JPH_BodyCreationSettings_Create3(
            @ptrCast(sphere_shape),
            &sphere_pos,
            null,
            c.JPH_MotionType_Dynamic,
            OBJECT_LAYER_MOVING,
        );
        defer c.JPH_BodyCreationSettings_Destroy(sphere_settings);

        sphere_id = c.JPH_BodyInterface_CreateAndAddBody(
            body_interface,
            sphere_settings,
            c.JPH_Activation_Activate,
        );
    }
    defer c.JPH_BodyInterface_RemoveAndDestroyBody(body_interface, sphere_id);

    const sphere_linear_velocity = c.JPH_Vec3{
        .x = 0,
        .y = -5,
        .z = 0,
    };
    c.JPH_BodyInterface_SetLinearVelocity(body_interface, sphere_id, &sphere_linear_velocity);

    const delta_time = 1.0 / 60.0;
    var step: u32 = 0;
    var sphere_active = true;
    while (sphere_active) {
        step += 1;

        var position: c.JPH_Vec3 = undefined;
        var velocity: c.JPH_Vec3 = undefined;

        c.JPH_BodyInterface_GetCenterOfMassPosition(body_interface, sphere_id, &position);
        c.JPH_BodyInterface_GetLinearVelocity(body_interface, sphere_id, &velocity);

        std.debug.print("Step = {}, Position = {}, Velocity = {}\n", .{ step, position, velocity });

        const err = c.JPH_PhysicsSystem_Update(physics_system, delta_time, 1, job_system);
        try testing.expect(err == c.JPH_PhysicsUpdateError_None);

        sphere_active = c.JPH_BodyInterface_IsActive(body_interface, sphere_id);

        if (step > 100) {
            std.debug.print("Failed to reach stable state", .{});
            break;
        }
    }
    try testing.expect(!sphere_active);
}
