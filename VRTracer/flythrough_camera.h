#ifndef FLYTHROUGH_CAMERA_H
#define FLYTHROUGH_CAMERA_H

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

// Flags for tweaking the view matrix
#define FLYTHROUGH_CAMERA_LEFT_HANDED_BIT 1

// * eye:
//     * Current eye position. Will be updated to new eye position.
// * look:
//     * Current look direction. Will be updated to new look direction.
// * up:
//     * Camera's "up" direction. Likely (0,1,0). Likely constant throughout application.
// * view (optional):
//     * The matrix that will be updated with the new view transform. Previous contents don't matter.
// * delta_time_seconds:
//     * Amount of seconds passed since last update.
// * eye_speed:
//     * How much the eye should move in world units per second.
// * degrees_per_cursor_move:
//     * How many degrees the camera rotates when the mouse moves by that many units.
// * max_pitch_rotation_degrees:
//     * How far up or down you're allowed to look.
//     * This prevents you from looking straight up or straight down,
//     * since being in alignment with the "up" direction leads to discontinuities.
//     * 0 degrees means you can't look up or down at all
//     * 80 degrees means you can almost look straight up, but not quite. (a good choice)
// * delta_cursor_x, delta_cursor_y:
//     * Update these every frame based on horizontal and vertical mouse movement.
// * forward_held, left_held, backward_held, right_held, jump_held, crouch_held:
//     * Update these every frame based on whether their associated keyboard keys are pressed.
//     * Example layout: W, A, S, D, space, ctrl
// * flags:
//     * For producing a different view matrix depending on your conventions.
void flythrough_camera_update(
    float eye[3],
    float look[3],
    const float up[3],
    float view[16],
    float delta_time_seconds,
    float eye_speed,
    float degrees_per_cursor_move,
    float max_pitch_rotation_degrees,
    int delta_cursor_x, int delta_cursor_y,
    int forward_held, int left_held, int backward_held, int right_held,
    int jump_held, int crouch_held,
    unsigned int flags);

// Utility for producing a look-to matrix without having to update a camera.
void flythrough_camera_look_to(
    const float eye[3],
    const float look[3],
    const float up[3],
    float view[16],
    unsigned int flags);

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // FLYTHROUGH_CAMERA_H


