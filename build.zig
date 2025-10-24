const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = .{
        .use_double_precision = b.option(
            bool,
            "use_double_precision",
            "Enable double precision",
        ) orelse false,
        .enable_asserts = b.option(
            bool,
            "enable_asserts",
            "Enable assertions",
        ) orelse (optimize == .Debug),
        .enable_cross_platform_determinism = b.option(
            bool,
            "enable_cross_platform_determinism",
            "Enables cross-platform determinism",
        ) orelse true,
        .enable_debug_renderer = b.option(
            bool,
            "enable_debug_renderer",
            "Enable debug renderer",
        ) orelse false,
        .shared = b.option(
            bool,
            "shared",
            "Build JoltC as shared lib",
        ) orelse false,
        .no_exceptions = b.option(
            bool,
            "no_exceptions",
            "Disable C++ Exceptions",
        ) orelse true,
    };

    const options_step = b.addOptions();
    inline for (std.meta.fields(@TypeOf(options))) |field| {
        options_step.addOption(field.type, field.name, @field(options, field.name));
    }

    const options_module = options_step.createModule();
    const mod = b.addModule("jolt_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "joltc_options",
                .module = options_module,
            },
        },
    });

    const joltc_dep = b.dependency("joltc", .{});
    const jph_dep = b.dependency("jolt_physics", .{});
    mod.addIncludePath(joltc_dep.path("include"));

    const jolt = b.addLibrary(
        .{
            .name = "jolt",
            .linkage = if (options.shared) .dynamic else .static,
            .root_module = b.createModule(
                .{
                    .target = target,
                    .optimize = optimize,
                },
            ),
        },
    );

    if (options.shared and target.result.os.tag == .windows) {
        jolt.root_module.addCMacro("JPH_API", "extern __declspec(dllexport)");
    }
    b.installArtifact(jolt);

    jolt.addIncludePath(joltc_dep.path("include"));
    jolt.addIncludePath(jph_dep.path(""));
    jolt.linkLibC();
    if (target.result.abi != .msvc) {
        jolt.linkLibCpp();
    } else {
        jolt.linkSystemLibrary("advapi32");
    }

    const c_flags = &.{
        "-std=c++17",
        if (options.no_exceptions) "-fno-exceptions" else "",
        "-fno-access-control",
        "-fno-sanitize=undefined",
    };

    jolt.addCSourceFiles(.{
        .root = joltc_dep.path("src"),
        .files = &.{
            "joltc.cpp",
        },
        .flags = c_flags,
    });

    jolt.addCSourceFiles(.{
        .root = jph_dep.path("Jolt"),
        .files = &.{
            "AABBTree/AABBTreeBuilder.cpp",
            "Core/Color.cpp",
            "Core/Factory.cpp",
            "Core/IssueReporting.cpp",
            "Core/JobSystemSingleThreaded.cpp",
            "Core/JobSystemThreadPool.cpp",
            "Core/JobSystemWithBarrier.cpp",
            "Core/LinearCurve.cpp",
            "Core/Memory.cpp",
            "Core/Profiler.cpp",
            "Core/RTTI.cpp",
            "Core/Semaphore.cpp",
            "Core/StringTools.cpp",
            "Core/TickCounter.cpp",
            "Geometry/ConvexHullBuilder.cpp",
            "Geometry/ConvexHullBuilder2D.cpp",
            "Geometry/Indexify.cpp",
            "Geometry/OrientedBox.cpp",
            "Math/Vec3.cpp",
            "ObjectStream/ObjectStream.cpp",
            "ObjectStream/ObjectStreamBinaryIn.cpp",
            "ObjectStream/ObjectStreamBinaryOut.cpp",
            "ObjectStream/ObjectStreamIn.cpp",
            "ObjectStream/ObjectStreamOut.cpp",
            "ObjectStream/ObjectStreamTextIn.cpp",
            "ObjectStream/ObjectStreamTextOut.cpp",
            "ObjectStream/SerializableObject.cpp",
            "ObjectStream/TypeDeclarations.cpp",
            "Physics/Body/Body.cpp",
            "Physics/Body/BodyCreationSettings.cpp",
            "Physics/Body/BodyInterface.cpp",
            "Physics/Body/BodyManager.cpp",
            "Physics/Body/MassProperties.cpp",
            "Physics/Body/MotionProperties.cpp",
            "Physics/Character/Character.cpp",
            "Physics/Character/CharacterBase.cpp",
            "Physics/Character/CharacterVirtual.cpp",
            "Physics/Collision/BroadPhase/BroadPhase.cpp",
            "Physics/Collision/BroadPhase/BroadPhaseBruteForce.cpp",
            "Physics/Collision/BroadPhase/BroadPhaseQuadTree.cpp",
            "Physics/Collision/BroadPhase/QuadTree.cpp",
            "Physics/Collision/CastConvexVsTriangles.cpp",
            "Physics/Collision/CastSphereVsTriangles.cpp",
            "Physics/Collision/CollideConvexVsTriangles.cpp",
            "Physics/Collision/CollideSphereVsTriangles.cpp",
            "Physics/Collision/CollisionDispatch.cpp",
            "Physics/Collision/CollisionGroup.cpp",
            "Physics/Collision/EstimateCollisionResponse.cpp",
            "Physics/Collision/GroupFilter.cpp",
            "Physics/Collision/GroupFilterTable.cpp",
            "Physics/Collision/ManifoldBetweenTwoFaces.cpp",
            "Physics/Collision/NarrowPhaseQuery.cpp",
            "Physics/Collision/NarrowPhaseStats.cpp",
            "Physics/Collision/PhysicsMaterial.cpp",
            "Physics/Collision/PhysicsMaterialSimple.cpp",
            "Physics/Collision/Shape/BoxShape.cpp",
            "Physics/Collision/Shape/CapsuleShape.cpp",
            "Physics/Collision/Shape/CompoundShape.cpp",
            "Physics/Collision/Shape/ConvexHullShape.cpp",
            "Physics/Collision/Shape/ConvexShape.cpp",
            "Physics/Collision/Shape/CylinderShape.cpp",
            "Physics/Collision/Shape/DecoratedShape.cpp",
            "Physics/Collision/Shape/EmptyShape.cpp",
            "Physics/Collision/Shape/HeightFieldShape.cpp",
            "Physics/Collision/Shape/MeshShape.cpp",
            "Physics/Collision/Shape/MutableCompoundShape.cpp",
            "Physics/Collision/Shape/OffsetCenterOfMassShape.cpp",
            "Physics/Collision/Shape/PlaneShape.cpp",
            "Physics/Collision/Shape/RotatedTranslatedShape.cpp",
            "Physics/Collision/Shape/ScaledShape.cpp",
            "Physics/Collision/Shape/Shape.cpp",
            "Physics/Collision/Shape/SphereShape.cpp",
            "Physics/Collision/Shape/StaticCompoundShape.cpp",
            "Physics/Collision/Shape/TaperedCapsuleShape.cpp",
            "Physics/Collision/Shape/TaperedCylinderShape.cpp",
            "Physics/Collision/Shape/TriangleShape.cpp",
            "Physics/Collision/TransformedShape.cpp",
            "Physics/Constraints/ConeConstraint.cpp",
            "Physics/Constraints/Constraint.cpp",
            "Physics/Constraints/ConstraintManager.cpp",
            "Physics/Constraints/ContactConstraintManager.cpp",
            "Physics/Constraints/DistanceConstraint.cpp",
            "Physics/Constraints/FixedConstraint.cpp",
            "Physics/Constraints/GearConstraint.cpp",
            "Physics/Constraints/HingeConstraint.cpp",
            "Physics/Constraints/MotorSettings.cpp",
            "Physics/Constraints/PathConstraint.cpp",
            "Physics/Constraints/PathConstraintPath.cpp",
            "Physics/Constraints/PathConstraintPathHermite.cpp",
            "Physics/Constraints/PointConstraint.cpp",
            "Physics/Constraints/PulleyConstraint.cpp",
            "Physics/Constraints/RackAndPinionConstraint.cpp",
            "Physics/Constraints/SixDOFConstraint.cpp",
            "Physics/Constraints/SliderConstraint.cpp",
            "Physics/Constraints/SpringSettings.cpp",
            "Physics/Constraints/SwingTwistConstraint.cpp",
            "Physics/Constraints/TwoBodyConstraint.cpp",
            "Physics/DeterminismLog.cpp",
            "Physics/IslandBuilder.cpp",
            "Physics/LargeIslandSplitter.cpp",
            "Physics/PhysicsScene.cpp",
            "Physics/PhysicsSystem.cpp",
            "Physics/PhysicsUpdateContext.cpp",
            "Physics/Ragdoll/Ragdoll.cpp",
            "Physics/SoftBody/SoftBodyCreationSettings.cpp",
            "Physics/SoftBody/SoftBodyMotionProperties.cpp",
            "Physics/SoftBody/SoftBodyShape.cpp",
            "Physics/SoftBody/SoftBodySharedSettings.cpp",
            "Physics/StateRecorderImpl.cpp",
            "Physics/Vehicle/MotorcycleController.cpp",
            "Physics/Vehicle/TrackedVehicleController.cpp",
            "Physics/Vehicle/VehicleAntiRollBar.cpp",
            "Physics/Vehicle/VehicleCollisionTester.cpp",
            "Physics/Vehicle/VehicleConstraint.cpp",
            "Physics/Vehicle/VehicleController.cpp",
            "Physics/Vehicle/VehicleDifferential.cpp",
            "Physics/Vehicle/VehicleEngine.cpp",
            "Physics/Vehicle/VehicleTrack.cpp",
            "Physics/Vehicle/VehicleTransmission.cpp",
            "Physics/Vehicle/Wheel.cpp",
            "Physics/Vehicle/WheeledVehicleController.cpp",
            "RegisterTypes.cpp",
            "Renderer/DebugRenderer.cpp",
            "Renderer/DebugRendererPlayback.cpp",
            "Renderer/DebugRendererRecorder.cpp",
            "Renderer/DebugRendererSimple.cpp",
            "Skeleton/SkeletalAnimation.cpp",
            "Skeleton/Skeleton.cpp",
            "Skeleton/SkeletonMapper.cpp",
            "Skeleton/SkeletonPose.cpp",
            "TriangleSplitter/TriangleSplitter.cpp",
            "TriangleSplitter/TriangleSplitterBinning.cpp",
            "TriangleSplitter/TriangleSplitterMean.cpp",
        },
        .flags = c_flags,
    });

    mod.linkLibrary(jolt);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
