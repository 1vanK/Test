// ==============================================
//
//    Root Motion Class
//
// ==============================================

const int LAYER_MOVE = 0;
const int LAYER_ATTACK = 1;

enum AttackType
{
    ATTACK_PUNCH,
    ATTACK_KICK,
};

void PlayAnimation(AnimationController@ ctrl, const String&in name, uint layer = LAYER_MOVE, bool loop = false, float blendTime = 0.1f, float startTime = 0.0f, float speed = 1.0f)
{
    //Print("PlayAnimation " + name + " loop=" + loop + " blendTime=" + blendTime + " startTime=" + startTime + " speed=" + speed);
    ctrl.StopLayer(layer, blendTime);
    ctrl.PlayExclusive(name, layer, loop, blendTime);
    ctrl.SetTime(name, startTime);
    ctrl.SetSpeed(name, speed);
}

int FindMotionIndex(const Array<Motion@>&in motions, const String&in name)
{
    for (uint i=0; i<motions.length; ++i)
    {
        if (motions[i].name == name)
            return i;
    }
    return -1;
}

void FillAnimationWithCurrentPose(Animation@ anim, Node@ _node)
{
    Array<String> boneNames =
    {
        "Bip01_$AssimpFbx$_Translation",
        "Bip01_$AssimpFbx$_PreRotation",
        "Bip01_$AssimpFbx$_Rotation",
        "Bip01_Pelvis",
        "Bip01_Spine",
        "Bip01_Spine1",
        "Bip01_Spine2",
        "Bip01_Spine3",
        "Bip01_Neck",
        "Bip01_Head",
        "Bip01_L_Thigh",
        "Bip01_L_Calf",
        "Bip01_L_Foot",
        "Bip01_R_Thigh",
        "Bip01_R_Calf",
        "Bip01_R_Foot",
        "Bip01_L_Clavicle",
        "Bip01_L_UpperArm",
        "Bip01_L_Forearm",
        "Bip01_L_Hand",
        "Bip01_R_Clavicle",
        "Bip01_R_UpperArm",
        "Bip01_R_Forearm",
        "Bip01_R_Hand"
    };

    anim.RemoveAllTracks();
    for (uint i=0; i<boneNames.length; ++i)
    {
        Node@ n = _node.GetChild(boneNames[i], true);
        if (n is null)
        {
            log.Error("FillAnimationWithCurrentPose can not find bone " + boneNames[i]);
            continue;
        }
        AnimationTrack@ track = anim.CreateTrack(boneNames[i]);
        track.channelMask = CHANNEL_POSITION | CHANNEL_ROTATION;
        AnimationKeyFrame kf;
        kf.time = 0.0f;
        kf.position = n.position;
        kf.rotation = n.rotation;
        track.AddKeyFrame(kf);
    }
}

int GetAttackType(const String&in name)
{
    if (name.Contains("Foot") || name.Contains("Calf"))
        return ATTACK_KICK;
    return ATTACK_PUNCH;
}

void DebugDrawDirection(DebugRenderer@ debug, Node@ _node, const Quaternion&in rotation, const Color&in color, float radius = 1.0, float yAdjust = 0)
{
    Vector3 dir = rotation * Vector3(0, 0, 1);
    float angle = Atan2(dir.x, dir.z);
    DebugDrawDirection(debug, _node, angle, color, radius, yAdjust);
}

void DebugDrawDirection(DebugRenderer@ debug, Node@ _node, float angle, const Color&in color, float radius = 1.0, float yAdjust = 0)
{
    Vector3 start = _node.worldPosition;
    start.y += yAdjust;
    Vector3 end = start + Vector3(Sin(angle) * radius, 0, Cos(angle) * radius);
    debug.AddLine(start, end, color, false);
}

void SendAnimationTriger(Node@ _node, const StringHash&in nameHash, int value = 0)
{
    VariantMap anim_data;
    anim_data[NAME] = nameHash;
    anim_data[VALUE] = value;
    VariantMap data;
    data[DATA] = anim_data;
    _node.SendEvent("AnimationTrigger", data);
}

Vector4 GetTargetTransform(Node@ baseNode, Motion@ alignMotion, Motion@ baseMotion)
{
    float r1 = alignMotion.GetStartRot();
    float r2 = baseMotion.GetStartRot();
    Vector3 s1 = alignMotion.GetStartPos();
    Vector3 s2 = baseMotion.GetStartPos();

    float baseYaw = baseNode.worldRotation.eulerAngles.y;
    float targetRotation = baseYaw + (r1 - r2);
    Vector3 diff_ws = Quaternion(0, baseYaw - r2, 0) * (s1 - s2);
    Vector3 targetPosition = baseNode.worldPosition + diff_ws;

    if (d_log)
    {
        Print("------------------------------------------------------------------------------------------------------------------------------------------------");
        Print("GetTargetTransform align-motion=" + alignMotion.name + " base-motion=" + baseMotion.name);
        Print("GetTargetTransform base=" + baseNode.name + " align-start-pos=" + s1.ToString() + " base-start-pos=" + s2.ToString() + " p-diff=" + (s1 - s2).ToString());
        Print("baseYaw=" + baseYaw + " targetRotation=" + targetRotation + " align-start-rot=" + r1 + " base-start-rot=" + r2 + " r-diff=" + (r1 - r2));
        Print("basePosition=" + baseNode.worldPosition.ToString() + " diff_ws=" + diff_ws.ToString() + " targetPosition=" + targetPosition.ToString());
        Print("------------------------------------------------------------------------------------------------------------------------------------------------");
    }

    return Vector4(targetPosition.x,  targetPosition.y, targetPosition.z, targetRotation);
}

class Motion
{
    String                  name;
    String                  animationName;
    StringHash              nameHash;

    Animation@              animation;
    Array<Vector4>          motionKeys;
    float                   endTime;
    bool                    looped;

    Vector4                 startFromOrigin;

    float                   endDistance;

    int                     endFrame;
    int                     motionFlag;
    int                     allowMotion;

    float                   rotateAngle = 361;

    bool                    processed = false;

    Motion()
    {
    }

    Motion(const Motion&in other)
    {
        animationName = other.animationName;
        animation = other.animation;
        motionKeys = other.motionKeys;
        endTime = other.endTime;
        looped = other.looped;
        startFromOrigin = other.startFromOrigin;
        endDistance = other.endDistance;
        endFrame = other.endFrame;
        motionFlag = other.motionFlag;
        allowMotion = other.allowMotion;
    }

    void SetName(const String&in _name)
    {
        name = _name;
        nameHash = StringHash(name);
    }

    ~Motion()
    {
        animation = null;
        cache.ReleaseResource("Animation", animationName);
    }

    void Process()
    {
        if (processed)
            return;
        uint startTime = time.systemTime;
        this.animationName = GetAnimationName(this.name);
        this.animation = cache.GetResource("Animation", animationName);
        if (this.animation is null)
            return;

        gMotionMgr.memoryUse += this.animation.memoryUse;
        rotateAngle = ProcessAnimation(animationName, motionFlag, allowMotion, rotateAngle, motionKeys, startFromOrigin);

        SetEndFrame(endFrame);
        Vector4 v = motionKeys[0];
        Vector4 diff = motionKeys[endFrame - 1] - motionKeys[0];
        endDistance = Vector3(diff.x, diff.y, diff.z).length;
        processed = true;
        //if (d_log)
        Print("Motion " + name + " endDistance="  + endDistance + " startFromOrigin=" + startFromOrigin.ToString()  + " timeCost=" + String(time.systemTime - startTime) + " ms");
    }

    void SetEndFrame(int frame)
    {
        endFrame = frame;
        if (endFrame < 0)
        {
            endFrame = motionKeys.length - 1;
            endTime = this.animation.length;
        }
        else
            endTime = float(endFrame) * SEC_PER_FRAME;
    }

    void GetMotion(float t, float dt, bool loop, Vector4& out out_motion)
    {
        if (motionKeys.empty)
            return;

        float future_time = t + dt;
        if (future_time > animation.length && loop) {
            Vector4 t1 = Vector4(0,0,0,0);
            Vector4 t2 = Vector4(0,0,0,0);
            GetMotion(t, animation.length - t, false, t1);
            GetMotion(0, t + dt - animation.length, false, t2);
            out_motion = t1 + t2;
        }
        else
        {
            Vector4 k1 = GetKey(t);
            Vector4 k2 = GetKey(future_time);
            out_motion = k2 - k1;
        }
    }

    Vector4 GetKey(float t)
    {
        if (motionKeys.empty)
            return Vector4(0, 0, 0, 0);

        uint i = uint(t * FRAME_PER_SEC);
        if (i >= motionKeys.length)
            i = motionKeys.length - 1;
        Vector4 k1 = motionKeys[i];
        uint next_i = i + 1;
        if (next_i >= motionKeys.length)
            next_i = motionKeys.length - 1;
        if (i == next_i)
            return k1;
        Vector4 k2 = motionKeys[next_i];
        float a = t*FRAME_PER_SEC - float(i);
        // float a =  (t - float(i)*SEC_PER_FRAME)/SEC_PER_FRAME;
        return k1.Lerp(k2, a);
    }

    Vector3 GetFuturePosition(Character@ object, float t)
    {
        Vector4 motionOut = GetKey(t);
        Node@ _node = object.GetNode();
        if (looped)
            return _node.worldRotation * Vector3(motionOut.x, motionOut.y, motionOut.z) + _node.worldPosition;
        else
            return Quaternion(0, object.motion_startRotation, 0) * Vector3(motionOut.x, motionOut.y, motionOut.z) + object.motion_startPosition;
    }

    float GetFutureRotation(Character@ object, float t)
    {
        return AngleDiff(object.GetNode().worldRotation.eulerAngles.y + GetKey(t).w);
    }

    void Start(Character@ object, float localTime = 0.0f, float blendTime = 0.1, float speed = 1.0f)
    {
        object.PlayAnimation(animationName, LAYER_MOVE, looped, blendTime, localTime, speed);
        InnerStart(object);
    }

    void InnerStart(Character@ object)
    {
        object.motion_startPosition = object.GetNode().worldPosition;
        object.motion_startRotation = object.GetNode().worldRotation.eulerAngles.y;
        object.motion_deltaRotation = 0;
        object.motion_deltaPosition = Vector3(0, 0, 0);
        object.motion_translateEnabled = true;
        object.motion_rotateEnabled = true;
        // Print("motion " + animationName + " start-position=" + object.motion_startPosition.ToString() + " start-rotation=" + object.motion_startRotation);
    }

    bool Move(Character@ object, float dt)
    {
        AnimationController@ ctrl = object.animCtrl;
        Node@ _node = object.GetNode();
        float localTime = ctrl.GetTime(animationName);

        if (looped)
        {
            Vector4 motionOut = Vector4(0, 0, 0, 0);
            GetMotion(localTime, dt, looped, motionOut);

            if (object.motion_rotateEnabled)
                _node.Yaw(motionOut.w);

            if (object.motion_translateEnabled)
            {
                Vector3 tLocal(motionOut.x, motionOut.y, motionOut.z);
                tLocal = tLocal * ctrl.GetWeight(animationName);
                Vector3 tWorld = _node.worldRotation * tLocal + _node.worldPosition + object.motion_deltaPosition;
                object.MoveTo(tWorld, dt);
            }
        }
        else
        {
            Vector4 motionOut = GetKey(localTime);
            if (object.motion_rotateEnabled)
                _node.worldRotation = Quaternion(0, object.motion_startRotation + motionOut.w + object.motion_deltaRotation, 0);

            if (object.motion_translateEnabled)
            {
                Vector3 tWorld = Quaternion(0, object.motion_startRotation, 0) * Vector3(motionOut.x, motionOut.y, motionOut.z) + object.motion_startPosition + object.motion_deltaPosition;
                //Print("tWorld=" + tWorld.ToString() + " cur-pos=" + object.GetNode().worldPosition.ToString() + " localTime=" + localTime);
                object.MoveTo(tWorld, dt);
            }
        }
        return localTime >= endTime;
    }

    void DebugDraw(DebugRenderer@ debug, Character@ object)
    {
        Node@ _node = object.GetNode();
        if (looped) {
            Vector4 tFinnal = GetKey(endTime);
            Vector3 tLocal(tFinnal.x, tFinnal.y, tFinnal.z);
            debug.AddLine(_node.worldRotation * tLocal + _node.worldPosition, _node.worldPosition, Color(0.5f, 0.5f, 0.7f), false);
        }
        else {
            Vector4 tFinnal = GetKey(endTime);
            Vector3 tMotionEnd = Quaternion(0, object.motion_startRotation, 0) * Vector3(tFinnal.x, tFinnal.y, tFinnal.z);
            debug.AddLine(tMotionEnd + object.motion_startPosition,  object.motion_startPosition, Color(0.5f, 0.5f, 0.7f), false);
            DebugDrawDirection(debug, _node, object.motion_startRotation + tFinnal.w, GREEN, 2.0);
        }
    }

    Vector3 GetStartPos()
    {
        return Vector3(startFromOrigin.x, startFromOrigin.y, startFromOrigin.z);
    }

    float GetStartRot()
    {
        return -rotateAngle;
    }
};

class AttackMotion
{
    Motion@                  motion;

    // ==============================================
    //   ATTACK VALUES
    // ==============================================

    float                   impactTime;
    float                   impactDist;;
    Vector3                 impactPosition;
    int                     type;
    String                  boneName;

    AttackMotion(const String&in name, int impactFrame, int _type, const String&in bName)
    {
        @motion = gMotionMgr.FindMotion(name);
        impactTime = impactFrame * SEC_PER_FRAME;
        Vector4 k = motion.motionKeys[impactFrame];
        impactPosition = Vector3(k.x, k.y, k.z);
        impactDist = impactPosition.length;
        type = _type;
        boneName = bName;
    }

    int opCmp(const AttackMotion&in obj)
    {
        if (impactDist > obj.impactDist)
            return 1;
        else if (impactDist < obj.impactDist)
            return -1;
        else
            return 0;
    }
};

class MotionManager
{
    Array<Motion@>          motions;
    uint                    assetProcessTime;
    int                     memoryUse;
    int                     processedMotions;

    MotionManager()
    {
        Print("MotionManager");
    }

    ~MotionManager()
    {
        Print("~MotionManager");
    }

    Motion@ FindMotion(StringHash nameHash)
    {
        for (uint i=0; i<motions.length; ++i)
        {
            if (motions[i].nameHash == nameHash)
                return motions[i];
        }
        return null;
    }

    Motion@ FindMotion(const String&in name)
    {
        Motion@ m = FindMotion(StringHash(name));
        if (m is null)
            log.Error("FindMotion Could not find " + name);
        return m;
    }

    void Start()
    {
        assetProcessTime = time.systemTime;
        AssetPreProcess();

        //========================================================================
        // PLAYER MOTIONS
        //========================================================================
        // Locomotions
        CreateMotion("BM_Combat_Movement/Turn_Right_90", kMotion_XZR, kMotion_R, 16);
        CreateMotion("BM_Combat_Movement/Turn_Right_180", kMotion_XZR, kMotion_R, 28);
        CreateMotion("BM_Combat_Movement/Turn_Left_90", kMotion_XZR, kMotion_R, 22);
        CreateMotion("BM_Combat_Movement/Walk_Forward", kMotion_XZR, kMotion_Z, -1, true);

        //CreateMotion("BM_Movement/Turn_Right_90", kMotion_R, kMotion_R, 16, 0, false);
        //CreateMotion("BM_Movement/Turn_Right_180", kMotion_R, kMotion_R, 25, 0, false);
        //CreateMotion("BM_Movement/Turn_Left_90", kMotion_R, kMotion_R, 14, 0, false);
        //CreateMotion("BM_Movement/Walk_Forward", kMotion_Z, kMotion_Z, -1, 0, true);

        // Evades
        CreateMotion("BM_Movement/Evade_Forward_01", kMotion_XZR, kMotion_XZR, 50);
        CreateMotion("BM_Movement/Evade_Back_01", kMotion_XZR, kMotion_XZR, 48);
        CreateMotion("BM_Movement/Evade_Left_01", kMotion_XZR, kMotion_XZR, 48);
        CreateMotion("BM_Movement/Evade_Right_01", kMotion_XZR, kMotion_XZR, 48);

        if (has_redirect)
            CreateMotion("BM_Combat/Redirect", kMotion_XZR, kMotion_XZR, 58);

        String preFix = "BM_Combat_HitReaction/";
        CreateMotion(preFix + "HitReaction_Back", kMotion_XZ); // back attacked
        CreateMotion(preFix + "HitReaction_Face_Right", kMotion_XZ); // front punched
        CreateMotion(preFix + "Hit_Reaction_SideLeft", kMotion_XZ); // left attacked
        CreateMotion(preFix + "Hit_Reaction_SideRight", kMotion_XZ); // right attacked
        //CreateMotion(preFix + "HitReaction_Stomach", kMotion_XZ); // be kicked ?
        //CreateMotion(preFix + "BM_Hit_Reaction", kMotion_XZ); // front heavy attacked

        // Attacks
        preFix = "BM_Attack/";
        //========================================================================
        // FORWARD
        //========================================================================
        // weak forward
        CreateMotion(preFix + "Attack_Close_Weak_Forward");
        CreateMotion(preFix + "Attack_Close_Weak_Forward_01");
        CreateMotion(preFix + "Attack_Close_Weak_Forward_02");
        CreateMotion(preFix + "Attack_Close_Weak_Forward_03");
        CreateMotion(preFix + "Attack_Close_Weak_Forward_04");
        CreateMotion(preFix + "Attack_Close_Weak_Forward_05");
        // close forward
        CreateMotion(preFix + "Attack_Close_Forward_02");
        CreateMotion(preFix + "Attack_Close_Forward_03");
        CreateMotion(preFix + "Attack_Close_Forward_04");
        CreateMotion(preFix + "Attack_Close_Forward_05");
        CreateMotion(preFix + "Attack_Close_Forward_06");
        CreateMotion(preFix + "Attack_Close_Forward_07");
        CreateMotion(preFix + "Attack_Close_Forward_08");
        CreateMotion(preFix + "Attack_Close_Run_Forward");
        // far forward
        CreateMotion(preFix + "Attack_Far_Forward");
        CreateMotion(preFix + "Attack_Far_Forward_01");
        CreateMotion(preFix + "Attack_Far_Forward_02");
        CreateMotion(preFix + "Attack_Far_Forward_03");
        CreateMotion(preFix + "Attack_Far_Forward_04");
        CreateMotion(preFix + "Attack_Run_Far_Forward");

        //========================================================================
        // RIGHT
        //========================================================================
        // weak right
        CreateMotion(preFix + "Attack_Close_Weak_Right");
        CreateMotion(preFix + "Attack_Close_Weak_Right_01");
        CreateMotion(preFix + "Attack_Close_Weak_Right_02");
        // close right
        CreateMotion(preFix + "Attack_Close_Right");
        CreateMotion(preFix + "Attack_Close_Right_01");
        CreateMotion(preFix + "Attack_Close_Right_03");
        CreateMotion(preFix + "Attack_Close_Right_04");
        CreateMotion(preFix + "Attack_Close_Right_05");
        CreateMotion(preFix + "Attack_Close_Right_06");
        CreateMotion(preFix + "Attack_Close_Right_07");
        CreateMotion(preFix + "Attack_Close_Right_08");
        // far right
        CreateMotion(preFix + "Attack_Far_Right");
        CreateMotion(preFix + "Attack_Far_Right_01");
        // CreateMotion(preFix + "Attack_Far_Right_02");
        CreateMotion(preFix + "Attack_Far_Right_03");
        CreateMotion(preFix + "Attack_Far_Right_04");

        //========================================================================
        // BACK
        //========================================================================
        // weak back
        CreateMotion(preFix + "Attack_Close_Weak_Back");
        CreateMotion(preFix + "Attack_Close_Weak_Back_01");
        // close back
        CreateMotion(preFix + "Attack_Close_Back");
        CreateMotion(preFix + "Attack_Close_Back_01");
        CreateMotion(preFix + "Attack_Close_Back_02");
        CreateMotion(preFix + "Attack_Close_Back_03");
        CreateMotion(preFix + "Attack_Close_Back_04");
        CreateMotion(preFix + "Attack_Close_Back_05");
        CreateMotion(preFix + "Attack_Close_Back_06");
        CreateMotion(preFix + "Attack_Close_Back_07");
        CreateMotion(preFix + "Attack_Close_Back_08");
        // far back
        CreateMotion(preFix + "Attack_Far_Back");
        CreateMotion(preFix + "Attack_Far_Back_01");
        CreateMotion(preFix + "Attack_Far_Back_02");
        //CreateMotion(preFix + "Attack_Far_Back_03");
        CreateMotion(preFix + "Attack_Far_Back_04");

        //========================================================================
        // LEFT
        //========================================================================
        // weak left
        CreateMotion(preFix + "Attack_Close_Weak_Left");
        CreateMotion(preFix + "Attack_Close_Weak_Left_01");
        CreateMotion(preFix + "Attack_Close_Weak_Left_02");

        // close left
        CreateMotion(preFix + "Attack_Close_Left");
        CreateMotion(preFix + "Attack_Close_Left_01");
        CreateMotion(preFix + "Attack_Close_Left_02");
        CreateMotion(preFix + "Attack_Close_Left_03");
        CreateMotion(preFix + "Attack_Close_Left_04");
        CreateMotion(preFix + "Attack_Close_Left_05");
        CreateMotion(preFix + "Attack_Close_Left_06");
        CreateMotion(preFix + "Attack_Close_Left_07");
        CreateMotion(preFix + "Attack_Close_Left_08");
        // far left
        CreateMotion(preFix + "Attack_Far_Left");
        CreateMotion(preFix + "Attack_Far_Left_01");
        CreateMotion(preFix + "Attack_Far_Left_02");
        CreateMotion(preFix + "Attack_Far_Left_03");
        CreateMotion(preFix + "Attack_Far_Left_04");

        preFix = "BM_TG_Counter/";
        AddCounterMotions(preFix);
        CreateMotion(preFix + "Double_Counter_2ThugsA", kMotion_XZR, kMotion_XZR, -1, false, 90);
        CreateMotion(preFix + "Double_Counter_2ThugsB", kMotion_XZR, kMotion_XZR, -1, false, 90);
        CreateMotion(preFix + "Double_Counter_2ThugsD", kMotion_XZR, kMotion_XZR, -1, false, -90);
        CreateMotion(preFix + "Double_Counter_2ThugsE");
        CreateMotion(preFix + "Double_Counter_2ThugsF");
        CreateMotion(preFix + "Double_Counter_2ThugsG");
        CreateMotion(preFix + "Double_Counter_2ThugsH");
        CreateMotion(preFix + "Double_Counter_3ThugsA", kMotion_XZR, kMotion_XZR, -1, false, 90);
        CreateMotion(preFix + "Double_Counter_3ThugsB", kMotion_XZR, kMotion_XZR, -1, false, -90);
        CreateMotion(preFix + "Double_Counter_3ThugsC", kMotion_XZR, kMotion_XZR, -1, false, -90);

        preFix = "BM_Death_Primers/";
        CreateMotion(preFix + "Death_Front");
        CreateMotion(preFix + "Death_Back");
        CreateMotion(preFix + "Death_Side_Left");
        CreateMotion(preFix + "Death_Side_Right");

        preFix = "BM_Attack/";
        //CreateMotion(preFix + "Beatdown_Strike_Start_01", kMotion_XZR, 0);
        //CreateMotion(preFix + "CapeDistract_Close_Forward");

        int beat_motion_flags = kMotion_XZR;
        int beat_allow_flags = kMotion_XZR;

        CreateMotion(preFix + "Beatdown_Test_01", beat_motion_flags, beat_allow_flags);
        CreateMotion(preFix + "Beatdown_Test_02", beat_motion_flags, beat_allow_flags);
        CreateMotion(preFix + "Beatdown_Test_03", beat_motion_flags, beat_allow_flags);
        CreateMotion(preFix + "Beatdown_Test_04", beat_motion_flags, beat_allow_flags);
        CreateMotion(preFix + "Beatdown_Test_05", beat_motion_flags, beat_allow_flags);
        CreateMotion(preFix + "Beatdown_Test_06", beat_motion_flags, beat_allow_flags);

        preFix = "BM_TG_Beatdown/";
        CreateMotion(preFix + "Beatdown_Strike_End_01");
        CreateMotion(preFix + "Beatdown_Strike_End_02");
        CreateMotion(preFix + "Beatdown_Strike_End_03");
        CreateMotion(preFix + "Beatdown_Strike_End_04");

        preFix = "BM_Combat/";
        // CreateMotion(preFix + "Attempt_Takedown", kMotion_XZR, kMotion_Z);
        CreateMotion(preFix + "Into_Takedown", kMotion_XZR, kMotion_XZR);

        //========================================================================
        // THUG MOTIONS
        //========================================================================
        preFix = "TG_Combat/";
        CreateMotion(preFix + "Step_Forward", kMotion_Z);
        CreateMotion(preFix + "Step_Right", kMotion_X);
        CreateMotion(preFix + "Step_Back", kMotion_Z);
        CreateMotion(preFix + "Step_Left", kMotion_X);
        CreateMotion(preFix + "Step_Forward_Long", kMotion_Z);
        CreateMotion(preFix + "Step_Right_Long", kMotion_X);
        CreateMotion(preFix + "Step_Back_Long", kMotion_Z);
        CreateMotion(preFix + "Step_Left_Long", kMotion_X);

        CreateMotion(preFix + "135_Turn_Left", kMotion_XZR, kMotion_R, 32);
        CreateMotion(preFix + "135_Turn_Right", kMotion_XZR, kMotion_R, 32);

        CreateMotion(preFix + "Run_Forward_Combat", kMotion_Z, kMotion_XZR, -1, true);
        CreateMotion(preFix + "Walk_Forward_Combat", kMotion_Z, kMotion_XZR, -1, true);

        if (has_redirect)
        {
            CreateMotion(preFix + "Redirect_push_back");
            CreateMotion(preFix + "Redirect_Stumble_JK");
        }

        CreateMotion(preFix + "Attack_Kick");
        CreateMotion(preFix + "Attack_Kick_01");
        CreateMotion(preFix + "Attack_Kick_02");
        CreateMotion(preFix + "Attack_Punch");
        CreateMotion(preFix + "Attack_Punch_01");
        CreateMotion(preFix + "Attack_Punch_02");


        preFix = "TG_HitReaction/";
        CreateMotion(preFix + "HitReaction_Left");
        CreateMotion(preFix + "HitReaction_Right");
        CreateMotion(preFix + "HitReaction_Back_NoTurn");
        CreateMotion(preFix + "HitReaction_Back");
        CreateMotion(preFix + "CapeDistract_Close_Forward");

        //CreateMotion(preFix + "Push_Reaction", kMotion_XZ);
        //CreateMotion(preFix + "Push_Reaction_From_Back", kMotion_XZ);

        preFix = "TG_Getup/";
        CreateMotion(preFix + "GetUp_Front", kMotion_XZ);
        CreateMotion(preFix + "GetUp_Back", kMotion_XZ);

        preFix = "TG_BM_Counter/";
        AddCounterMotions(preFix);
        CreateMotion(preFix + "Double_Counter_2ThugsA_01");
        CreateMotion(preFix + "Double_Counter_2ThugsA_02");
        CreateMotion(preFix + "Double_Counter_2ThugsB_01", kMotion_XZR, kMotion_XZR, -1, false, -90);
        CreateMotion(preFix + "Double_Counter_2ThugsB_02", kMotion_XZR, kMotion_XZR, -1, false, 90);
        CreateMotion(preFix + "Double_Counter_2ThugsD_01");
        CreateMotion(preFix + "Double_Counter_2ThugsD_02");
        CreateMotion(preFix + "Double_Counter_2ThugsE_01");
        CreateMotion(preFix + "Double_Counter_2ThugsE_02");
        CreateMotion(preFix + "Double_Counter_2ThugsF_01");
        CreateMotion(preFix + "Double_Counter_2ThugsF_02");
        CreateMotion(preFix + "Double_Counter_2ThugsG_01");
        CreateMotion(preFix + "Double_Counter_2ThugsG_02", kMotion_XZR, kMotion_XZR, -1, false, 90);
        CreateMotion(preFix + "Double_Counter_2ThugsH_01");
        CreateMotion(preFix + "Double_Counter_2ThugsH_02", kMotion_XZR, kMotion_XZR, -1, false, 90);
        CreateMotion(preFix + "Double_Counter_3ThugsA_01", kMotion_XZR, kMotion_XZR, -1, false, -90);
        CreateMotion(preFix + "Double_Counter_3ThugsA_02");
        CreateMotion(preFix + "Double_Counter_3ThugsA_03", kMotion_XZR, kMotion_XZR, -1, false, 90);
        CreateMotion(preFix + "Double_Counter_3ThugsB_01");
        CreateMotion(preFix + "Double_Counter_3ThugsB_02", kMotion_XZR, kMotion_XZR, -1, false, 90);
        CreateMotion(preFix + "Double_Counter_3ThugsB_03");
        CreateMotion(preFix + "Double_Counter_3ThugsC_01");
        CreateMotion(preFix + "Double_Counter_3ThugsC_02", kMotion_XZR, kMotion_XZR, -1, false, 90);
        CreateMotion(preFix + "Double_Counter_3ThugsC_03");

        preFix = "TG_BM_Beatdown/";
        // CreateMotion(preFix + "Beatdown_Start_01", kMotion_XZR, 0);
        CreateMotion(preFix + "Beatdown_HitReaction_01", beat_motion_flags, beat_allow_flags);
        CreateMotion(preFix + "Beatdown_HitReaction_02", beat_motion_flags, beat_allow_flags);
        CreateMotion(preFix + "Beatdown_HitReaction_03", beat_motion_flags, beat_allow_flags);
        CreateMotion(preFix + "Beatdown_HitReaction_04", beat_motion_flags, beat_allow_flags);
        CreateMotion(preFix + "Beatdown_HitReaction_05", beat_motion_flags, beat_allow_flags);
        CreateMotion(preFix + "Beatdown_HitReaction_06", beat_motion_flags, beat_allow_flags);

        CreateMotion(preFix + "Beatdown_Strike_End_01");
        CreateMotion(preFix + "Beatdown_Strike_End_02");
        CreateMotion(preFix + "Beatdown_Strike_End_03");
        CreateMotion(preFix + "Beatdown_Strike_End_04");
    }

    void Stop()
    {
        motions.Clear();
    }

    Motion@ CreateMotion(const String&in name, int motionFlag = kMotion_XZR, int allowMotion = kMotion_XZR,  int endFrame = -1, bool loop = false, float rotateAngle = 361)
    {
        Motion@ motion = Motion();
        motion.SetName(name);
        motion.motionFlag = motionFlag;
        motion.allowMotion = allowMotion;
        motion.looped = loop;
        motion.endFrame = endFrame;
        motion.rotateAngle = rotateAngle;
        motions.Push(motion);
        return motion;
    }

    bool Update(float dt)
    {
        if (processedMotions >= int(motions.length))
            return true;
        uint t = time.systemTime;
        int len = int(motions.length);
        for (int i=processedMotions; i<len; ++i)
        {
            motions[i].Process();
            ++processedMotions;
            int time_diff = int(time.systemTime - t);
            if (time_diff >= PROCESS_TIME_PER_FRAME)
                break;
        }
        Print("MotionManager Process this frame time=" + (time.systemTime - t) + " ms " + " processedMotions=" + processedMotions);
        return processedMotions >= int(motions.length);
    }

    void ProcessAll()
    {
        for (uint i=0; i<motions.length; ++i)
            motions[i].Process();
    }

    Motion@ CreateCustomMotion(Motion@ refMotion, const String&in name)
    {
        Motion@ motion = Motion(refMotion);
        motion.SetName(name);
        motions.Push(motion);
        return motion;
    }

    void AddCounterMotions(const String&in counter_prefix)
    {
        CreateMotion(counter_prefix + "Counter_Arm_Back_01");
        CreateMotion(counter_prefix + "Counter_Arm_Back_02");
        CreateMotion(counter_prefix + "Counter_Arm_Back_03");
        CreateMotion(counter_prefix + "Counter_Arm_Back_05");
        CreateMotion(counter_prefix + "Counter_Arm_Back_06");

        CreateMotion(counter_prefix + "Counter_Arm_Back_Weak_01");
        CreateMotion(counter_prefix + "Counter_Arm_Back_Weak_02");
        CreateMotion(counter_prefix + "Counter_Arm_Back_Weak_03");

        CreateMotion(counter_prefix + "Counter_Arm_Front_01");
        CreateMotion(counter_prefix + "Counter_Arm_Front_02");
        CreateMotion(counter_prefix + "Counter_Arm_Front_03");
        CreateMotion(counter_prefix + "Counter_Arm_Front_04");
        CreateMotion(counter_prefix + "Counter_Arm_Front_05");
        CreateMotion(counter_prefix + "Counter_Arm_Front_06");
        CreateMotion(counter_prefix + "Counter_Arm_Front_07");
        CreateMotion(counter_prefix + "Counter_Arm_Front_08");
        CreateMotion(counter_prefix + "Counter_Arm_Front_09");
        CreateMotion(counter_prefix + "Counter_Arm_Front_10");
        CreateMotion(counter_prefix + "Counter_Arm_Front_13");
        CreateMotion(counter_prefix + "Counter_Arm_Front_14");

        CreateMotion(counter_prefix + "Counter_Arm_Front_Weak_02");
        CreateMotion(counter_prefix + "Counter_Arm_Front_Weak_03");
        CreateMotion(counter_prefix + "Counter_Arm_Front_Weak_04");

        CreateMotion(counter_prefix + "Counter_Leg_Back_01");
        CreateMotion(counter_prefix + "Counter_Leg_Back_02");
        CreateMotion(counter_prefix + "Counter_Leg_Back_03");
        CreateMotion(counter_prefix + "Counter_Leg_Back_04");
        CreateMotion(counter_prefix + "Counter_Leg_Back_05");

        CreateMotion(counter_prefix + "Counter_Leg_Back_Weak_01");
        CreateMotion(counter_prefix + "Counter_Leg_Back_Weak_03");

        CreateMotion(counter_prefix + "Counter_Leg_Front_01");
        CreateMotion(counter_prefix + "Counter_Leg_Front_02");
        CreateMotion(counter_prefix + "Counter_Leg_Front_03");
        CreateMotion(counter_prefix + "Counter_Leg_Front_04");
        CreateMotion(counter_prefix + "Counter_Leg_Front_05");
        CreateMotion(counter_prefix + "Counter_Leg_Front_06");
        CreateMotion(counter_prefix + "Counter_Leg_Front_07");
        CreateMotion(counter_prefix + "Counter_Leg_Front_08");
        CreateMotion(counter_prefix + "Counter_Leg_Front_09");

        CreateMotion(counter_prefix + "Counter_Leg_Front_Weak");
        CreateMotion(counter_prefix + "Counter_Leg_Front_Weak_01");
        CreateMotion(counter_prefix + "Counter_Leg_Front_Weak_02");
    }

    void Finish()
    {
        PostProcess();
        AssetPostProcess();
        Print("************************************************************************************************");
        Print("Motion Process time-cost=" + String(time.systemTime - assetProcessTime) + " ms num-of-motions=" + motions.length + " memory-use=" + String(memoryUse/1024) + " KB");
        Print("************************************************************************************************");
    }

    void PostProcess()
    {
        uint t = time.systemTime;

        //thug animation triggers
        AddThugAnimationTriggers();

        // Player animation triggers
        AddPlayerAnimationTriggers();

        Print("MotionManager::PostProcess time-cost=" + (time.systemTime - t) + " ms");
    }

     void AddThugAnimationTriggers()
    {
        String preFix = "TG_BM_Counter/";
        AddRagdollTrigger(preFix + "Counter_Leg_Front_01", 30, 35);
        AddRagdollTrigger(preFix + "Counter_Leg_Front_02", 46, 56);
        AddRagdollTrigger(preFix + "Counter_Leg_Front_03", 38, 48);
        AddRagdollTrigger(preFix + "Counter_Leg_Front_04", 30, 46);
        AddRagdollTrigger(preFix + "Counter_Leg_Front_05", 38, 42);
        AddRagdollTrigger(preFix + "Counter_Leg_Front_06", 32, 36);
        AddRagdollTrigger(preFix + "Counter_Leg_Front_07", 56, 60);
        AddRagdollTrigger(preFix + "Counter_Leg_Front_08", 50, 52);
        AddRagdollTrigger(preFix + "Counter_Leg_Front_09", 36, 38);

        AddRagdollTrigger(preFix + "Counter_Arm_Front_01", 34, 35);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_02", 44, 48);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_03", 35, 40);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_04", 36, 40);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_05", 60, 66);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_06", -1, 44);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_07", 38, 43);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_08", 54, 60);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_09", 60, 68);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_10", -1, 56);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_13", 58, 68);
        AddRagdollTrigger(preFix + "Counter_Arm_Front_14", 72, 78);

        AddRagdollTrigger(preFix + "Counter_Arm_Back_01", 35, 40);
        AddRagdollTrigger(preFix + "Counter_Arm_Back_02", -1, 48);
        AddRagdollTrigger(preFix + "Counter_Arm_Back_03", 30, 35);
        AddRagdollTrigger(preFix + "Counter_Arm_Back_05", 40, 48);
        AddRagdollTrigger(preFix + "Counter_Arm_Back_06", 65, 70);

        AddRagdollTrigger(preFix + "Counter_Leg_Back_01", 50, 54);
        AddRagdollTrigger(preFix + "Counter_Leg_Back_02", 60, 54);
        AddRagdollTrigger(preFix + "Counter_Leg_Back_03", -1, 72);
        AddRagdollTrigger(preFix + "Counter_Leg_Back_04", -1, 43);
        AddRagdollTrigger(preFix + "Counter_Leg_Back_05", 48, 52);

        AddAnimationTrigger(preFix + "Counter_Arm_Back_Weak_01", 50, READY_TO_FIGHT);
        AddAnimationTrigger(preFix + "Counter_Arm_Back_Weak_02", 40, READY_TO_FIGHT);
        AddAnimationTrigger(preFix + "Counter_Arm_Back_Weak_03", 88, READY_TO_FIGHT);

        AddAnimationTrigger(preFix + "Counter_Arm_Front_Weak_02", 50, READY_TO_FIGHT);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_Weak_03", 100, READY_TO_FIGHT);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_Weak_04", 70, READY_TO_FIGHT);

        AddAnimationTrigger(preFix + "Counter_Leg_Back_Weak_01", 55, READY_TO_FIGHT);
        AddAnimationTrigger(preFix + "Counter_Leg_Back_Weak_03", 76, READY_TO_FIGHT);

        AddAnimationTrigger(preFix + "Counter_Leg_Front_Weak", 50, READY_TO_FIGHT);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_Weak_01", 65, READY_TO_FIGHT);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_Weak_02", 65, READY_TO_FIGHT);

        AddRagdollTrigger(preFix + "Double_Counter_2ThugsA_01", -1, 99);
        AddRagdollTrigger(preFix + "Double_Counter_2ThugsA_02", -1, 99);

        AddRagdollTrigger(preFix + "Double_Counter_2ThugsB_01", -1, 58);
        AddRagdollTrigger(preFix + "Double_Counter_2ThugsB_02", -1, 58);

        AddRagdollTrigger(preFix + "Double_Counter_2ThugsD_01", -1, 48);
        AddRagdollTrigger(preFix + "Double_Counter_2ThugsD_02", -1, 48);

        AddRagdollTrigger(preFix + "Double_Counter_2ThugsE_01", 80, 84);
        AddRagdollTrigger(preFix + "Double_Counter_2ThugsE_02", 80, 84);

        AddRagdollTrigger(preFix + "Double_Counter_2ThugsF_01", 26, 28);
        AddRagdollTrigger(preFix + "Double_Counter_2ThugsF_02", 19, 24);

        AddRagdollTrigger(preFix + "Double_Counter_2ThugsG_01", -1, 26);
        AddRagdollTrigger(preFix + "Double_Counter_2ThugsG_02", -1, 26);

        AddRagdollTrigger(preFix + "Double_Counter_2ThugsH_01", -1, 62);
        AddRagdollTrigger(preFix + "Double_Counter_2ThugsH_02", -1, 62);

        AddRagdollTrigger(preFix + "Double_Counter_3ThugsA_01", 24, 30);
        AddRagdollTrigger(preFix + "Double_Counter_3ThugsA_02", 30, 36);
        AddRagdollTrigger(preFix + "Double_Counter_3ThugsA_03", 26, 34);

        AddRagdollTrigger(preFix + "Double_Counter_3ThugsB_01", 25, 33);
        AddRagdollTrigger(preFix + "Double_Counter_3ThugsB_02", 25, 33);
        AddRagdollTrigger(preFix + "Double_Counter_3ThugsB_03", 25, 33);

        AddRagdollTrigger(preFix + "Double_Counter_3ThugsC_01", 35, 41);
        AddRagdollTrigger(preFix + "Double_Counter_3ThugsC_02", 35, 45);
        AddRagdollTrigger(preFix + "Double_Counter_3ThugsC_03", 35, 45);

        /*
        preFix = "TG_BM_Beatdown/";
        AddRagdollTrigger(preFix + "Beatdown_Strike_End_01", 24, 28);
        AddIntAnimationTrigger(preFix + "Beatdown_Strike_End_01", 28, HEALTH, 0);
        AddRagdollTrigger(preFix + "Beatdown_Strike_End_02", -1, 48);
        AddIntAnimationTrigger(preFix + "Beatdown_Strike_End_02", 48, HEALTH, 0);
        AddRagdollTrigger(preFix + "Beatdown_Strike_End_03", -1, 28);
        AddIntAnimationTrigger(preFix + "Beatdown_Strike_End_03", 28, HEALTH, 0);
        AddRagdollTrigger(preFix + "Beatdown_Strike_End_04", -1, 50);
        AddIntAnimationTrigger(preFix + "Beatdown_Strike_End_04", 50, HEALTH, 0);
        */

        //preFix = "TG_HitReaction/";
        //AddRagdollTrigger(preFix + "Push_Reaction", 6, 12);
        //AddRagdollTrigger(preFix + "Push_Reaction_From_Back", 6, 9);

        preFix = "TG_Combat/";
        int frame_fixup = 6;
        // name counter-start counter-end attack-start attack-end attack-bone
        AddComplexAttackTrigger(preFix + "Attack_Kick", 15 - frame_fixup, 24, 24, 27, "Bip01_L_Foot");
        AddComplexAttackTrigger(preFix + "Attack_Kick_01", 12 - frame_fixup, 24, 24, 27, "Bip01_L_Foot");
        AddComplexAttackTrigger(preFix + "Attack_Kick_02", 19 - frame_fixup, 24, 24, 27, "Bip01_L_Foot");
        AddComplexAttackTrigger(preFix + "Attack_Punch", 15 - frame_fixup, 22, 22, 24, "Bip01_R_Hand");
        AddComplexAttackTrigger(preFix + "Attack_Punch_01", 15 - frame_fixup, 23, 23, 24, "Bip01_R_Hand");
        AddComplexAttackTrigger(preFix + "Attack_Punch_02", 15 - frame_fixup, 23, 23, 24, "Bip01_R_Hand");

        AddStringAnimationTrigger(preFix + "Run_Forward_Combat", 2, FOOT_STEP, L_FOOT);
        AddStringAnimationTrigger(preFix + "Run_Forward_Combat", 13, FOOT_STEP, R_FOOT);

        AddStringAnimationTrigger(preFix + "Step_Back", 15, FOOT_STEP, R_FOOT);
        AddStringAnimationTrigger(preFix + "Step_Back_Long", 9, FOOT_STEP, R_FOOT);
        AddStringAnimationTrigger(preFix + "Step_Back_Long", 19, FOOT_STEP, L_FOOT);

        AddStringAnimationTrigger(preFix + "Step_Forward", 12, FOOT_STEP, L_FOOT);
        AddStringAnimationTrigger(preFix + "Step_Forward_Long", 10, FOOT_STEP, L_FOOT);
        AddStringAnimationTrigger(preFix + "Step_Forward_Long", 22, FOOT_STEP, R_FOOT);

        AddStringAnimationTrigger(preFix + "Step_Left", 11, FOOT_STEP, L_FOOT);
        AddStringAnimationTrigger(preFix + "Step_Left_Long", 8, FOOT_STEP, L_FOOT);
        AddStringAnimationTrigger(preFix + "Step_Left_Long", 22, FOOT_STEP, R_FOOT);

        AddStringAnimationTrigger(preFix + "Step_Right", 11, FOOT_STEP, R_FOOT);
        AddStringAnimationTrigger(preFix + "Step_Right_Long", 15, FOOT_STEP, R_FOOT);
        AddStringAnimationTrigger(preFix + "Step_Right_Long", 28, FOOT_STEP, L_FOOT);

        AddStringAnimationTrigger(preFix + "135_Turn_Left", 8, FOOT_STEP, R_FOOT);
        AddStringAnimationTrigger(preFix + "135_Turn_Left", 20, FOOT_STEP, L_FOOT);
        AddStringAnimationTrigger(preFix + "135_Turn_Left", 31, FOOT_STEP, R_FOOT);

        AddStringAnimationTrigger(preFix + "135_Turn_Right", 11, FOOT_STEP, R_FOOT);
        AddStringAnimationTrigger(preFix + "135_Turn_Right", 24, FOOT_STEP, L_FOOT);
        AddStringAnimationTrigger(preFix + "135_Turn_Right", 39, FOOT_STEP, R_FOOT);

        preFix = "TG_Getup/";
        AddAnimationTrigger(preFix + "GetUp_Front", 44, READY_TO_FIGHT);
        AddAnimationTrigger(preFix + "GetUp_Back", 68, READY_TO_FIGHT);
    }

    void AddPlayerAnimationTriggers()
    {
        String preFix = "BM_TG_Counter/";
        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_01", 9, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_01", 38, COMBAT_SOUND, R_ARM);
        AddAnimationTrigger(preFix + "Counter_Arm_Back_01", 40, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_02", 8, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_02", 41, COMBAT_SOUND, R_FOOT);
        AddAnimationTrigger(preFix + "Counter_Arm_Back_02", 43, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_03", 6, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_03", 17, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_03", 33, COMBAT_SOUND, L_FOOT);
        AddAnimationTrigger(preFix + "Counter_Arm_Back_03", 35, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_05", 26, COMBAT_SOUND, R_ARM);
        AddAnimationTrigger(preFix + "Counter_Arm_Back_05", 28, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_06", 50, COMBAT_SOUND, R_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Back_06", 52, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_Weak_01", 11, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_Weak_01", 25, COMBAT_SOUND, R_ARM);
        AddAnimationTrigger(preFix + "Counter_Arm_Back_Weak_01", 27, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_Weak_02", 6, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_Weak_02", 16, COMBAT_SOUND, R_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Back_Weak_02", 18, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Back_Weak_03", 26, COMBAT_SOUND, R_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Back_Weak_03", 28, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_01", 9, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_01", 17, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_01", 34, COMBAT_SOUND, R_FOOT);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_01", 36, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_02", 9, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_02", 22, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_02", 45, COMBAT_SOUND, R_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_02", 47, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_03", 9, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_03", 39, COMBAT_SOUND, R_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_03", 41, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_04", 12, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_04", 34, COMBAT_SOUND, R_ARM);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_03", 41, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_05", 7, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_05", 26, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_05", 43, COMBAT_SOUND, L_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_05", 45, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_06", 5, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_06", 18, COMBAT_SOUND, R_FOOT);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_06", 38, COMBAT_SOUND, L_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_06", 40, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_07", 6, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_07", 24, COMBAT_SOUND, L_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_07", 26, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_08", 4, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_08", 11, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_08", 30, COMBAT_SOUND, R_ARM);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_08", 32, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_09", 6, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_09", 22, COMBAT_SOUND, L_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_09", 39, COMBAT_SOUND, R_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_09", 41, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_10", 10, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_10", 23, COMBAT_SOUND, L_FOOT);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_10", 25, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_13", 21, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_13", 40, COMBAT_SOUND, L_FOOT);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_13", 42, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_14", 10, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_14", 22, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_14", 50, COMBAT_SOUND, R_FOOT);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_14", 52, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_Weak_02", 4, COMBAT_SOUND, L_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_Weak_02", 9, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_Weak_02", 21, COMBAT_SOUND, L_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_Weak_02", 23, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_Weak_03", 4, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_Weak_03", 15, COMBAT_SOUND, L_HAND);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_Weak_03", 17, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_Weak_04", 5, COMBAT_SOUND, L_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Arm_Front_Weak_04", 16, COMBAT_SOUND, R_ARM);
        AddAnimationTrigger(preFix + "Counter_Arm_Front_Weak_04", 18, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_01", 9, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_01", 17, COMBAT_SOUND, L_FOOT);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_01", 46, COMBAT_SOUND, R_ARM);
        AddAnimationTrigger(preFix + "Counter_Leg_Back_01", 48, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_02", 7, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_02", 15, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_02", 46, COMBAT_SOUND, L_CALF);
        AddAnimationTrigger(preFix + "Counter_Leg_Back_02", 48, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_03", 11, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_03", 24, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_03", 47, COMBAT_SOUND, L_HAND);
        AddAnimationTrigger(preFix + "Counter_Leg_Back_02", 49, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_04", 9, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_04", 31, COMBAT_SOUND, L_FOOT);
        AddAnimationTrigger(preFix + "Counter_Leg_Back_04", 33, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_05", 7, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_05", 29, COMBAT_SOUND, R_HAND);
        AddAnimationTrigger(preFix + "Counter_Leg_Back_05", 31, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_Weak_01", 7, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_Weak_01", 30, COMBAT_SOUND, R_ARM);
        AddAnimationTrigger(preFix + "Counter_Leg_Back_Weak_01", 32, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_Weak_03", 11, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Back_Weak_03", 38, COMBAT_SOUND, L_ARM);
        AddAnimationTrigger(preFix + "Counter_Leg_Back_Weak_03", 40, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_01", 11, COMBAT_SOUND, L_FOOT);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_01", 30, COMBAT_SOUND, L_FOOT);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_01", 32, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_02", 6, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_02", 15, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_02", 42, COMBAT_SOUND, L_CALF);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_02", 44, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_03", 3, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_03", 22, COMBAT_SOUND, L_HAND);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_03", 24, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_04", 7, COMBAT_SOUND, L_FOOT);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_04", 30, COMBAT_SOUND, R_FOOT);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_04", 32, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_05", 5, COMBAT_SOUND, L_FOOT);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_05", 18, COMBAT_SOUND, L_FOOT);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_05", 38, COMBAT_SOUND, R_FOOT);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_05", 40, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_06", 6, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_06", 18, COMBAT_SOUND, L_HAND);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_06", 20, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_07", 8, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_07", 42, COMBAT_SOUND, R_FOOT);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_07", 44, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_08", 8, COMBAT_SOUND, R_ARM);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_08", 21, COMBAT_SOUND, L_HAND);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_08", 23, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_09", 6, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_09", 27, COMBAT_SOUND, R_HAND);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_09", 29, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_Weak", 12, COMBAT_SOUND, L_FOOT);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_Weak", 18, COMBAT_SOUND, L_FOOT);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_Weak", 20, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_Weak_01", 3, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_Weak_01", 21, COMBAT_SOUND, R_HAND);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_Weak_01", 23, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_Weak_02", 6, COMBAT_SOUND, L_FOOT);
        AddStringAnimationTrigger(preFix + "Counter_Leg_Front_Weak_02", 21, COMBAT_SOUND, L_ARM);
        AddAnimationTrigger(preFix + "Counter_Leg_Front_Weak_02", 23, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsA", 12, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsA", 12, PARTICLE, R_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsA", 77, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsA", 77, PARTICLE, R_HAND);
        AddAnimationTrigger(preFix + "Double_Counter_2ThugsA", 79, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsB", 12, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsB", 36, IMPACT, L_HAND);
        AddAnimationTrigger(preFix + "Double_Counter_2ThugsB", 60, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsD", 7, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsD", 7, PARTICLE, R_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsD", 15, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsD", 38, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsD", 38, PARTICLE, R_HAND);
        AddAnimationTrigger(preFix + "Double_Counter_2ThugsD", 43, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsE", 21, IMPACT, R_ARM);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsE", 43, IMPACT, L_FOOT);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsE", 76, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsE", 83, IMPACT, L_HAND);
        AddAnimationTrigger(preFix + "Double_Counter_2ThugsE", 85, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsF", 26, IMPACT, L_FOOT);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsF", 26, PARTICLE, R_FOOT);
        AddAnimationTrigger(preFix + "Double_Counter_2ThugsF", 60, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsG", 23, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsG", 23, PARTICLE, R_HAND);
        AddAnimationTrigger(preFix + "Double_Counter_2ThugsG", 25, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsH", 21, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsH", 21, PARTICLE, R_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsH", 36, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_2ThugsH", 36, PARTICLE, R_HAND);
        AddAnimationTrigger(preFix + "Double_Counter_2ThugsH", 65, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Double_Counter_3ThugsA", 5, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_3ThugsA", 7, IMPACT, R_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_3ThugsA", 26, IMPACT, R_HAND);
        AddAnimationTrigger(preFix + "Double_Counter_3ThugsA", 35, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Double_Counter_3ThugsB", 27, IMPACT, R_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_3ThugsB", 27, PARTICLE, L_FOOT);
        AddStringAnimationTrigger(preFix + "Double_Counter_3ThugsB", 27, PARTICLE, R_FOOT);
        AddAnimationTrigger(preFix + "Double_Counter_3ThugsB", 50, READY_TO_FIGHT);

        AddStringAnimationTrigger(preFix + "Double_Counter_3ThugsC", 5, IMPACT, L_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_3ThugsC", 5, PARTICLE, R_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_3ThugsC", 37, IMPACT, R_HAND);
        AddStringAnimationTrigger(preFix + "Double_Counter_3ThugsC", 37, PARTICLE, L_FOOT);
        AddAnimationTrigger(preFix + "Double_Counter_3ThugsC", 52, READY_TO_FIGHT);

        preFix = "BM_Combat_Movement/";
        AddStringAnimationTrigger(preFix + "Walk_Forward", 11, FOOT_STEP, R_FOOT);
        AddStringAnimationTrigger(preFix + "Walk_Forward", 24, FOOT_STEP, L_FOOT);

        AddStringAnimationTrigger(preFix + "Turn_Right_90", 11, FOOT_STEP, R_FOOT);
        AddStringAnimationTrigger(preFix + "Turn_Right_90", 15, FOOT_STEP, L_FOOT);

        AddStringAnimationTrigger(preFix + "Turn_Right_180", 13, FOOT_STEP, R_FOOT);
        AddStringAnimationTrigger(preFix + "Turn_Right_180", 20, FOOT_STEP, L_FOOT);

        AddStringAnimationTrigger(preFix + "Turn_Left_90", 13, FOOT_STEP, L_FOOT);
        AddStringAnimationTrigger(preFix + "Turn_Left_90", 20, FOOT_STEP, R_FOOT);

        preFix = "BM_Attack/";
        AddAnimationTrigger(preFix + "CapeDistract_Close_Forward", 12, IMPACT);

        int beat_impact_frame = 4;
        AddAnimationTrigger(preFix + "Beatdown_Test_01", beat_impact_frame, IMPACT);
        AddAnimationTrigger(preFix + "Beatdown_Test_02", beat_impact_frame, IMPACT);
        AddAnimationTrigger(preFix + "Beatdown_Test_03", beat_impact_frame, IMPACT);
        AddAnimationTrigger(preFix + "Beatdown_Test_04", beat_impact_frame, IMPACT);
        AddAnimationTrigger(preFix + "Beatdown_Test_05", beat_impact_frame, IMPACT);
        AddAnimationTrigger(preFix + "Beatdown_Test_06", beat_impact_frame, IMPACT);

        AddStringAnimationTrigger(preFix + "Beatdown_Test_01", beat_impact_frame, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Beatdown_Test_02", beat_impact_frame, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Beatdown_Test_03", beat_impact_frame, COMBAT_SOUND, L_HAND);
        AddStringAnimationTrigger(preFix + "Beatdown_Test_04", beat_impact_frame, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Beatdown_Test_05", beat_impact_frame, COMBAT_SOUND, R_HAND);
        AddStringAnimationTrigger(preFix + "Beatdown_Test_06", beat_impact_frame, COMBAT_SOUND, R_HAND);

        //AddStringAnimationTrigger(preFix + "Beatdown_Strike_Start_01", 7, COMBAT_SOUND, L_HAND);

        preFix = "BM_TG_Beatdown/";
        AddStringAnimationTrigger(preFix + "Beatdown_Strike_End_01", 16, IMPACT, R_HAND);
        AddStringAnimationTrigger(preFix + "Beatdown_Strike_End_02", 30, IMPACT, HEAD);
        AddStringAnimationTrigger(preFix + "Beatdown_Strike_End_03", 24, IMPACT, R_FOOT);
        AddStringAnimationTrigger(preFix + "Beatdown_Strike_End_04", 28, IMPACT, L_CALF);
    }
};


MotionManager@ gMotionMgr = MotionManager();