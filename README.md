# ludum-dare-46

## Introduction

This is a game made on PICO-8 for LudumDare 46

The theme of the jam is "Keep it alive".

In our game the player has to drive an ambulence through a city to help people and bring them to the hospital. When drifting or hitting walls, the patient can be hurt. The goal is to leave them to the hospital alive as fast as possible. There are power-ups on the road to help the player in his task.

The game features solo and split-screen mutiplayer.

## Physics

To achieve a somewhat realistic driving we needed a way to separate the physics code and the driving code. Then came the idea of a homemade and extensible physics engine.

### Transforms

As the ambulence is driving, it can move and turn. A simple way to achieve this effect is by adding transforms to our engine.

A transform is defined by a position and a rotation. The position is a simple 2D vector and the rotation a floating point number.

Handling transformation between object space and world space is done quite easily with a rotation matrix and vector additions

### Colliders

The next step is to be able to check overlaps between shapes. To keep the code simple, our collider is an extension to the transform. As a consequence, every function that works on transforms are also available for colliders.

To keep it simple we decided to implement box colliders only. A box is defined by a position, a rotation, a width and a height. The two first properties are already defined by the inheritance from transform.

A classical algorithm used to detect collisions between boxes is an algorithm called *AABB collision detection*. This method is cpu-friendly as it simply compares the corners of two axis-aligned boxes. However, our colliders can be rotated and therefore we have to transform the coorditates back and forth between the collider's local space and the world space. Hopefully the cpu cost for this operation is quite light.

### Rigidbodies

Here comes the fun part. Now we have to be able to move our colliders in a physically accurate way.

In newtonian physics an object can be defined by a position, a rotation, a shape, a velocity, an acceleration, a torque and finally an angular velocity. Extending our colliders with the four last properties is exactly what we need.

Simulating a rigidbody without collisions is quite simple. Every frame we do the following calculation for the position. (The calculation for rotation is very similar)
```
new velocity = old velocity + acceleration * timestep
new position = old position + new velocity * timestep
```
As the game runs on a discrete time basis, we have to simulate the time derivative using the elapsed time since last frame (which is either 1/30 or 1/60 on pico-8).

When you add collision detection, you also have to figure out what the new velocity should be in order to avoid colliders overlapping.

To achieve this, when a collision occurs we compute the normal vector of the surface we hit, and use it to modify the velocity. As our colliders are boxes, we just have to know what edge is being hit on the hit collider to get the normal vector. During the AABB collision detection, we compute the average point of contact. We can use this information to get the edge. A sequence of if statements comparing the angle made between the collider's right vector and the contact point and some threshold values is enough and done easily.

Once the normal computation is done, we can compute the new velocity. Using Newton's third law of motion, we now that the response force is directed along the surface normal, and depends on the velocity of the rigidbody along this axis.
```
speed along normal =  old velocity ⸳ surface normal
velocity delta = speed along normal x surface normal
new velocity = old velocity - velocity delta
```
We can also add a bounce effect by using
```
velocity delta = velocity delta * (1 + bounciness)
```
where bounciness is a value between 0 (no bounce) and 1 (perfect bounce)

With the collision response algorithm done we just have to loop through every collider we hit and update the theoretical new position and velocity.

Once we finished looping through the colliders we can update the rigidbody properties.

Adding static collisions with the map is made using a easy trick. Right before updating the rigidbody's properties, we can check if it would overlap a solid map cell. In case of an overlap, we just create a temporary collider for that cell and do all the previous calculation for the response. You can of course check the pixel color instead, or whatever is your static object.

## Split-screen multiplayer

One way to add fun to your pico-8 game is adding multiplayer. However when the map is too large and players too far apart one of them has to be off-screen. A solution to this problem is to split the screen and give a half to each player.

Pico-8 API allows you to directly access the screen memory and manipulate it. We'll use it to create the effect. The general idea is as follow
```
render for player1
copy memory from half the screen to an empty memory space
render for player2
copy memory from previous memory space back to the screen
maybe draw a line to separate the two halves
```
The screen memory size is 128x128 bytes long. Since we copy half of it we need an empty memory space of 128x64 bytes. In our game we used the shared memory between sprites and map, which is exactly 128x64 bytes long.
Using pico-8's documentation for memory mapping we have:
```lua
-- render for player1
memcpy(0x1000, 0x6000, 0xfff)
-- render for player2
memcpy(0x6000, 0x1000, 0xfff)
-- draw a line to separate the screens
```
You may have to offset the camera and UI when rendering for player1 and player2 in order for them to be properly centered on their screen.

As you may have noticed, our solution requires to leave the second half of the spritesheet and the bottom half of the map to work properly without affecting the rest of the game.

You can of course customize your split and make it vertical or tilted, or even split the screen into more parts. You just have to figure out what are the memory adresses to copy from and to.